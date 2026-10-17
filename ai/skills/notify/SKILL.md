---
name: notify
description: Send a short message to the user on Slack, as a DM by default or to a named channel. Used by loop, simplify, and automations to report results.
---

`$ARGUMENTS`: `[to=me|<channel ID>] [thread=<ts>] <message>`. Default `to=me`.

1. `to=me` → get the user's Slack ID from `slack_read_user_profile` with no arguments.
2. Through `mux-mcp-gateway`, list the `slack` server's tools with `mux_mcp_list_tools`, then call the exact `slack_send_message` name it returns via `mux_mcp_call` with `server_id: "slack"`, `tool_name`, and `channel_id` set to the user or channel ID; with `thread=`, also `thread_ts`. Hosted tool names can carry a prefix, so never guess the name. Make the send a direct tool call, never inside a batched script: batched sends are held for a confirmation that never comes in an unattended run.
3. Write standard Markdown, which the tool converts: `[text](url)` links, `**bold**`, lists, small tables. Under 5,000 characters per message. A format the caller specifies wins.
4. Return the message link and its `ts`, so a caller can reply in the thread.
5. Slack unreachable → put the message in your final reply and say it was not sent.

Never post anywhere the caller did not name.

Known limit: messages go out as the user, and Slack does not notify anyone of their own messages, so a DM to `me` arrives without a notification.
