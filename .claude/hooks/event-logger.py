#!/usr/bin/env python3
"""
Claude Code Event Logger Hook

This hook collects events from Claude Code and writes them to a JSONL file
for consumption by claude-tail or other log viewers.

Events are written to: ~/.claude/events.jsonl
"""
import json
import os
import sys
from datetime import datetime
from pathlib import Path


def get_log_path() -> Path:
    """Get the path to the events log file."""
    return Path.home() / ".claude" / "events.jsonl"


def log_event(event_data: dict) -> None:
    """Append an event to the log file."""
    log_file = get_log_path()
    log_file.parent.mkdir(parents=True, exist_ok=True)

    with open(log_file, 'a', encoding='utf-8') as f:
        f.write(json.dumps(event_data, default=str) + '\n')


def extract_role(input_data: dict) -> str:
    """Determine the role (user or assistant) from the event."""
    event_type = input_data.get('hook_event_name', '')

    if event_type == 'UserPromptSubmit':
        return 'user'
    elif event_type in ('Stop', 'AssistantResponse'):
        return 'assistant'
    elif event_type in ('PreToolUse', 'PostToolUse'):
        return 'assistant'  # Tools are used by the assistant

    return ''


def extract_content(input_data: dict) -> str:
    """Extract the main content from the event."""
    event_type = input_data.get('hook_event_name', '')

    if event_type == 'UserPromptSubmit':
        return input_data.get('prompt', '')

    # For tool uses, we might want to show a summary
    tool_input = input_data.get('tool_input', {})
    if isinstance(tool_input, dict):
        # For Read/Write/Edit, show file path
        if 'file_path' in tool_input:
            return tool_input.get('file_path', '')
        # For Bash, show command
        if 'command' in tool_input:
            cmd = tool_input.get('command', '')
            # Truncate very long commands
            if len(cmd) > 500:
                cmd = cmd[:500] + '...'
            return cmd
        # For Grep/Glob, show pattern
        if 'pattern' in tool_input:
            return tool_input.get('pattern', '')

    return ''


def main():
    """Main entry point for the hook."""
    try:
        # Read input from stdin
        input_text = sys.stdin.read()
        if not input_text.strip():
            sys.exit(0)

        input_data = json.loads(input_text)

        # Build the event record
        event = {
            'timestamp': datetime.now().isoformat(),
            'session_id': input_data.get('session_id', ''),
            'event_type': input_data.get('hook_event_name', ''),
            'role': extract_role(input_data),
            'tool_name': input_data.get('tool_name', ''),
            'content': extract_content(input_data),
            'message_type': input_data.get('message_type', ''),
        }

        # Include tool input for tool use events (but sanitize)
        if input_data.get('hook_event_name') in ('PreToolUse', 'PostToolUse'):
            tool_input = input_data.get('tool_input', {})
            if isinstance(tool_input, dict):
                # Only include key fields to avoid huge logs
                sanitized_input = {}
                for key in ('command', 'file_path', 'path', 'pattern', 'query', 'prompt', 'description'):
                    if key in tool_input:
                        value = tool_input[key]
                        # Truncate long values
                        if isinstance(value, str) and len(value) > 500:
                            value = value[:500] + '...'
                        sanitized_input[key] = value
                event['tool_input'] = sanitized_input

        # Log the event
        log_event(event)

        # Exit successfully (don't block the hook)
        sys.exit(0)

    except json.JSONDecodeError as e:
        # Log parse errors but don't block
        print(f"JSON parse error: {e}", file=sys.stderr)
        sys.exit(0)
    except Exception as e:
        # Log errors but don't block Claude Code
        print(f"Hook error: {e}", file=sys.stderr)
        sys.exit(0)


if __name__ == '__main__':
    main()
