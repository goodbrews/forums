require 'capistrano-rbenv'
require 'bundler/capistrano'
require 'sidekiq/capistrano'
require 'new_relic/recipes'

# Repo Settings
# Cloned to a private copy of discourse
set :repository, 'git@github.com:goodbrews/forums.git'
set :deploy_via, :remote_cache
set :branch, fetch(:branch, 'master')
set :scm, :git
ssh_options[:forward_agent] = true

# General Settings
set :deploy_type, :deploy
default_run_options[:pty] = true
ssh_options[:keys] = [File.join(ENV['HOME'], '.ssh', 'goodbrews')]

# Server Settings
set :user, 'goodbrews'
set :use_sudo, false
set :rails_env, :production
set :rbenv_ruby_version, '2.0.0-p0'

role :app, 'forums.goodbre.ws', primary: true
role :db,  'forums.goodbre.ws', primary: true
role :web, 'forums.goodbre.ws', primary: true

# Application Settings
set :application, 'discourse'
set :deploy_to, "/home/#{user}/#{application}"

# Hooks
after "deploy:setup" do
  run "cd #{current_path} && bundle install"
end

# Configuration
namespace :deploy do
  desc 'Start thin servers'
  task :start, :roles => :app, :except => { :no_release => true } do
    run "cd #{current_path} && RUBY_GC_MALLOC_LIMIT=90000000 bundle exec thin -C config/thin.yml start", :pty => false
  end

  desc 'Stop thin servers'
  task :stop, :roles => :app, :except => { :no_release => true } do
    run "cd #{current_path} && bundle exec thin -C config/thin.yml stop"
  end

  desc 'Restart thin servers'
  task :restart, :roles => :app, :except => { :no_release => true } do
    run "cd #{current_path} && RUBY_GC_MALLOC_LIMIT=90000000 bundle exec thin -C config/thin.yml restart"
  end

  task :setup_config, roles: :app do
    run  "mkdir -p #{shared_path}/config/initializers"
    run  "mkdir -p #{shared_path}/config/environments"
    run  "mkdir -p #{shared_path}/sockets"
    put  File.read("config/database.yml"), "#{shared_path}/config/database.yml"
    put  File.read("config/newrelic.yml"), "#{shared_path}/config/newrelic.yml"
    put  File.read("config/nginx.conf"),   "#{shared_path}/config/nginx.conf"
    put  File.read("config/redis.yml"),    "#{shared_path}/config/redis.yml"
    put  File.read("config/environments/production.rb"), "#{shared_path}/config/environments/production.rb"
    put  File.read("config/initializers/secret_token.rb"), "#{shared_path}/config/initializers/secret_token.rb"
    sudo "ln -nfs #{shared_path}/config/nginx.conf /etc/nginx/sites-enabled/#{application}"
    puts "Now edit the config files in #{shared_path}."
  end

  task :symlink_config, roles: :app do
    run  "ln -nfs #{shared_path}/config/database.yml #{release_path}/config/database.yml"
    run  "ln -nfs #{shared_path}/config/newrelic.yml #{release_path}/config/newrelic.yml"
    run  "ln -nfs #{shared_path}/config/redis.yml #{release_path}/config/redis.yml"
    run  "ln -nfs #{shared_path}/config/environments/production.rb #{release_path}/config/environments/production.rb"
    run  "ln -nfs #{shared_path}/config/initializers/secret_token.rb #{release_path}/config/initializers/secret_token.rb"
  end
end

after "deploy:setup", "deploy:setup_config"
after "deploy:finalize_update", "deploy:symlink_config"

namespace :clockwork do
  desc "Start clockwork"
  task :start, :roles => [:app] do
    run "cd #{current_path} && RAILS_ENV=#{rails_env} bundle exec clockworkd -c #{current_path}/config/clock.rb --pid-dir #{shared_path}/pids --log --log-dir #{shared_path}/log start"
  end

  task :stop, :roles => [:app] do
    run "cd #{current_path} && RAILS_ENV=#{rails_env} bundle exec clockworkd -c #{current_path}/config/clock.rb --pid-dir #{shared_path}/pids --log --log-dir #{shared_path}/log stop"
  end

  task :restart, :roles => [:app] do
    run "cd #{current_path} && RAILS_ENV=#{rails_env} bundle exec clockworkd -c #{current_path}/config/clock.rb --pid-dir #{shared_path}/pids --log --log-dir #{shared_path}/log restart"
  end
end

after  "deploy:stop",    "clockwork:stop"
after  "deploy:start",   "clockwork:start"
before "deploy:restart", "clockwork:restart"

after  'deploy:update', 'newrelic:notice_deployment'
after  'deploy:update_code', 'deploy:migrate'
