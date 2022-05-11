
def run_zauth_app_template(path)
  system "#{RbConfig.ruby} ./bin/rails app:template LOCATION=#{File.expand_path("../install/#{path}.rb", __dir__)}"
end

namespace :zauth do
  desc "Install ZAuth modules into the app"
  task :install do
    run_zauth_app_template('zauth_app_template')
  end
end
