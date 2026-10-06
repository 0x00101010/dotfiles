import type { PluginAPI } from '@ampcode/plugin'

export const description =
	'Adds review_with_models: runs read-only PR reviewer briefs in parallel on two models from different providers, at a deep or light cost tier.'

const TIERS = {
	deep: [
		{ model: 'anthropic/claude-fable-5-1', reasoningEffort: 'high' },
		{ model: 'openai/gpt-6-astra', reasoningEffort: 'high' },
	],
	light: [
		{ model: 'anthropic/claude-opus-5-5', reasoningEffort: 'medium' },
		{ model: 'openai/gpt-6.1-sol', reasoningEffort: 'medium' },
	],
} as const

type Tier = keyof typeof TIERS

const INSTRUCTIONS = `You are a read-only code reviewer. Never edit files, commit, push, comment, or resolve threads. Use shell commands only to read (git diff, git log, rg, cat) or run tests. Follow the brief and reply only in its output format.`

const describeTier = (tier: Tier) => TIERS[tier].map((m) => `${m.model} (${m.reasoningEffort})`).join(' + ')

export default function (amp: PluginAPI) {
	const reviewers = Object.fromEntries(
		(Object.keys(TIERS) as Tier[]).map((tier) => [
			tier,
			TIERS[tier].map((m) => ({
				label: `${m.model} (${m.reasoningEffort})`,
				agent: amp.createAgent({
					name: 'reviewer',
					model: m.model,
					reasoningEffort: m.reasoningEffort,
					instructions: INSTRUCTIONS,
					tools: ['Read', 'finder', 'shell_command', 'shell_command_status'],
				}),
			})),
		]),
	) as Record<Tier, { label: string; agent: ReturnType<PluginAPI['createAgent']> }[]>

	amp.registerTool({
		name: 'review_with_models',
		title: 'Multi-model review',
		transcriptGroup: { active: 'Reviewing', complete: 'Reviewed' },
		description: `Run read-only reviewers in parallel. Each task runs once on each of the tier's two models, from different providers. deep: ${describeTier('deep')}. light: ${describeTier('light')}. Returns every reviewer's output, labeled by task and model.`,
		inputSchema: {
			type: 'object',
			properties: {
				tier: { type: 'string', enum: Object.keys(TIERS) },
				tasks: {
					type: 'array',
					minItems: 1,
					items: {
						type: 'object',
						properties: {
							name: { type: 'string', description: 'Short label, e.g. the lens name.' },
							prompt: { type: 'string', description: 'Complete, self-contained reviewer brief.' },
						},
						required: ['name', 'prompt'],
					},
				},
			},
			required: ['tier', 'tasks'],
		},
		async execute(input, ctx) {
			const { tier, tasks } = input as { tier: Tier; tasks: { name: string; prompt: string }[] }
			const runs = tasks.flatMap((task) => reviewers[tier].map((reviewer) => ({ task, reviewer })))
			const results = await Promise.allSettled(
				runs.map(({ task, reviewer }) =>
					reviewer.agent.run(task.prompt, { parentThreadID: ctx.thread.id, timeoutMs: 30 * 60_000 }),
				),
			)
			return results
				.map((result, i) => {
					const { task, reviewer } = runs[i]
					const body = result.status === 'fulfilled' ? result.value.text : `FAILED: ${result.reason}`
					return `## ${task.name} · ${reviewer.label}\n\n${body}`
				})
				.join('\n\n')
		},
	})
}
