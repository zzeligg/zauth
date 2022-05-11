
say "Creating app/controllers/concerns/authentication_control.rb"
copy_file "#{__dir__}/templates/authentication_control_template.rb", "app/controllers/concerns/authentication_control.rb"

say "Creating app/models/concerns/authenticated_model.rb"
copy_file "#{__dir__}/templates/authenticated_model_template.rb", "app/models/concerns/authenticated_model.rb"

if yes?("Would you like to install the TOTP module (for multifactor authentication)?")
  gem 'rotp'
  say "Creating app/models/concerns/totp_auth.rb"
  copy_file "#{__dir__}/templates/totp_auth_template.rb", "app/models/concerns/totp_auth.rb"
end