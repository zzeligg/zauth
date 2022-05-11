
# Zauth - A bootstrapper for authentication flow in a Ruby on Rails application

This is an intentionally simple gem to facilitate installation of source files required
for basic authentication controller and model functionality in a Rails app.

I packaged this into a gem to simplify usage in [Rails application templates](https://guides.rubyonrails.org/rails_application_templates.html)

## Usage:

```bash
> bin/rails zauth:install
```

It install 2 files:

  1. A module named `AuthenticatedModel` in `app/models/concerns/authenticated_model.rb` which provides methods for a `User` model to be authenticated by password.

  2. A module named `AuthenticationControl` in `app/controllers/concerns/authentication_control.rb` which provides methods for controllers in your application to deal with authentication states and flow control.


TO BE CONTINUED...
