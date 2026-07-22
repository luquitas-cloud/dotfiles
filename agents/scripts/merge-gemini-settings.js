#!/usr/bin/osascript -l JavaScript
// Merge portable context, skills, and command guard settings into Gemini CLI.

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

function unique(values) {
  return values.filter((value, index) => values.indexOf(value) === index);
}

function run(argv) {
  if (argv.length !== 2) {
    throw new Error("usage: merge-gemini-settings.js INPUT OUTPUT");
  }

  const input = argv[0];
  const output = argv[1];
  const settings = input === "-" ? {} : JSON.parse(readText(input));

  settings.context = settings.context || {};
  let contextNames = settings.context.fileName || [];
  if (typeof contextNames === "string") {
    contextNames = [contextNames];
  }
  settings.context.fileName = unique(["AGENTS.md", "GEMINI.md"].concat(contextNames));

  settings.skills = settings.skills || {};
  settings.skills.enabled = true;
  settings.hooksConfig = settings.hooksConfig || {};
  settings.hooksConfig.enabled = true;
  settings.hooks = settings.hooks || {};
  settings.hooks.BeforeTool = settings.hooks.BeforeTool || [];

  const managed = {
    matcher: "run_shell_command",
    hooks: [
      {
        name: "portable-machine-policy",
        type: "command",
        command: 'DOTFILES_AGENT_RUNTIME=gemini bash "$HOME/.gemini/hooks/guard.sh"',
        timeout: 10000,
      },
    ],
  };

  settings.hooks.BeforeTool = settings.hooks.BeforeTool.filter(
    (group) =>
      !(group.hooks || []).some(
        (hook) =>
          typeof hook.command === "string" &&
          hook.command.includes(".gemini/hooks/guard.sh"),
      ),
  );
  settings.hooks.BeforeTool.push(managed);

  writeText(output, `${JSON.stringify(settings, null, 2)}\n`);
}
