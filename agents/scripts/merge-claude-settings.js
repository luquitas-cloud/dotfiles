#!/usr/bin/osascript -l JavaScript
// Merge the portable permission mode and command guard into Claude settings.

ObjC.import("Foundation");

function readText(path) {
  const value = $.NSString.stringWithContentsOfFileEncodingError(
    path,
    $.NSUTF8StringEncoding,
    null,
  );
  if (!value) {
    throw new Error(`Unable to read ${path}`);
  }
  return ObjC.unwrap(value);
}

function writeText(path, text) {
  const value = $.NSString.alloc.initWithUTF8String(text);
  if (!value.writeToFileAtomicallyEncodingError(path, true, $.NSUTF8StringEncoding, null)) {
    throw new Error(`Unable to write ${path}`);
  }
}

function run(argv) {
  if (argv.length !== 2) {
    throw new Error("usage: merge-claude-settings.js INPUT OUTPUT");
  }

  const input = argv[0];
  const output = argv[1];
  const settings = input === "-" ? {} : JSON.parse(readText(input));

  settings.permissions = settings.permissions || {};
  // High autonomy baseline: auto-approve tools. Hard stops stay in the shared command guard.
  settings.permissions.defaultMode = "bypassPermissions";
  settings.hooks = settings.hooks || {};
  settings.hooks.PreToolUse = settings.hooks.PreToolUse || [];

  const managed = {
    matcher: "^Bash$",
    hooks: [
      {
        type: "command",
        command: 'bash "$HOME/.claude/hooks/guard.sh"',
        timeout: 10,
        statusMessage: "Enforcing portable machine policy",
      },
    ],
  };

  settings.hooks.PreToolUse = settings.hooks.PreToolUse.filter(
    (group) =>
      !(group.hooks || []).some(
        (hook) =>
          typeof hook.command === "string" &&
          hook.command.includes(".claude/hooks/guard.sh"),
      ),
  );
  settings.hooks.PreToolUse.push(managed);

  writeText(output, `${JSON.stringify(settings, null, 2)}\n`);
}
