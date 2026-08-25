// Tailwind config for the admin console's stylesheet (app/assets/tailwind/active_admin.css).
//
// Upstream Active Admin imports its plugin as '@activeadmin/activeadmin/plugin',
// which needs a node_modules tree. This app has no Node toolchain and builds CSS
// with the standalone Tailwind binary from tailwindcss-ruby, which cannot resolve
// bare package specifiers — so the gem's own copy of the plugin is located
// through Bundler and imported by absolute path instead.
import { execSync } from 'child_process';

// Always use the last line of output since Bundler's DEBUG env will print additional lines.
const activeAdminPath = execSync('bundle show activeadmin', { encoding: 'utf-8' }).trim().split(/\r?\n/).pop();
const activeAdminPlugin = (await import(`${activeAdminPath}/plugin.js`)).default;

export default {
  content: [
    `${activeAdminPath}/vendor/javascript/flowbite.js`,
    `${activeAdminPath}/plugin.js`,
    `${activeAdminPath}/app/views/**/*.{arb,erb,html,rb}`,
    './app/admin/**/*.{arb,erb,html,rb}',
    './app/views/active_admin/**/*.{arb,erb,html,rb}',
    './app/views/admin/**/*.{arb,erb,html,rb}',
    './app/javascript/**/*.js'
  ],
  darkMode: "selector",
  plugins: [
    activeAdminPlugin
  ]
}
