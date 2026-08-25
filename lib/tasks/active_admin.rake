# tailwindcss-rails builds a single entry point (app/assets/tailwind/application.css).
# The admin console needs a second one, built with its own config so that Active
# Admin's plugin — which restyles every form control it sees — stays out of the
# public site's stylesheet.
namespace :active_admin do
  namespace :tailwindcss do
    compile_command = lambda do |args|
      command = [
        Tailwindcss::Ruby.executable,
        "-i", Rails.root.join("app/assets/tailwind/active_admin.css").to_s,
        "-o", Rails.root.join("app/assets/builds/active_admin.css").to_s
      ]
      command << "--minify" unless args.extras.include?("debug")
      command << "--silent" if args.extras.include?("silent")
      command
    end

    desc "Build the admin console's Tailwind CSS"
    task build: :environment do |_, args|
      system(*compile_command.call(args), exception: true)
    end

    desc "Watch and build the admin console's Tailwind CSS on file changes"
    task watch: :environment do |_, args|
      command = compile_command.call(args) + [ "-w" ]
      command << "always" if args.extras.include?("always")
      Tailwindcss::ProcessRunner.spawn_and_wait({}, *command)
    end
  end
end

# Ride along with the app's own stylesheet, so `assets:precompile` and
# `test:prepare` build both.
Rake::Task["tailwindcss:build"].enhance([ "active_admin:tailwindcss:build" ])
