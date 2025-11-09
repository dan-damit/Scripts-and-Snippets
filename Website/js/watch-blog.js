const fs = require("fs");
const { exec } = require("child_process");

const target = "blog.md";
const parser = "md-to-json.js";

console.log(`👀 Watching ${target} for changes...`);

fs.watch(target, (eventType) => {
  if (eventType === "change") {
    console.log(`🔄 Detected update to ${target}. Running parser...`);
    exec(`node ${parser}`, (err, stdout, stderr) => {
      if (err) {
        console.error(`❌ Error: ${err.message}`);
        return;
      }
      if (stderr) {
        console.error(`⚠️ stderr: ${stderr}`);
      }
      console.log(`✅ ${parser} completed:\n${stdout}`);
    });
  }
});
