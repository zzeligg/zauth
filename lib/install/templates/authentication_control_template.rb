# Include this module in your controller to enable the authentication system for that
# controller
#
# == Setting up the authentication control system ==
#
# 1. Define an instance method on the controller class to define which model is the
#    Authenticatable class (i.e the "User" class)
#
#    You must define a method named `auth_model_class` for the controller that includes
#    this module. `auth_model_class` must return the model to use as a "User" class. For
#    example, if the model representing your users is named `Person``, then you must define
#    a protected method in your controller that will return that class. See example below.
#
#    Of course, the model you specify must include the AuthenticatedModel module (concern).
#
# 2. Define an instance method on the controller class that will define the session Hash key 
#    to store the user id.
#
#    You must define a method named `session_auth_key` for the controller that includes
#    this module. `session_auth_key` must return a symbol to use as the key in the session
#    Hash that stores the ID of an authentified user.
#
#    This is especially important if you will have more than one session namespaces and
#    more than a single user model that can be authentified.
#
#    For example, you may have a Person model that will be authenticated in the /public/
#    section of your application, and a Admin model that will be authenticated in the
#    /admin/ section. If an authenticated Person with ID = 1 tries to access the /admin/
#    section, then the value in the session must be different, otherwise, the Person will be
#    considered as the Admin with the same ID. By using different keys in the session Hash,
#    you ensure that Person and Admin sessions will not collide.
#
# 3. Define the session Hash key to store current location
#
#    You must define a method named `session_location_store_key` in the controller class
#    that includes this module. `session_location_store_key` must return a symbol to use
#    as the key to store the request_uri that will be used to perform redirections after
#    logins and logouts by users.
#
# 4. Define if single device sessions should be enabled. When enabled, the model class must 
#    have a persisted attribute (table column) named 
#
# == Example Use ==
#
# class ApplicationController < ActionController::Base
#    include AuthenticationControl
#    ...
#    protected
#
#    def auth_model_class
#       Person
#    end
#
#    def session_auth_key
#       :person_auth_id
#    end
#
#    def session_location_store_key
#       :return_to
#    end
#
#    # defaults to true in staging and production environment, so override in controller if needed
#    def single_device_sessions 
#      AppConfig.single_device_sessions
#    end
#
#    ...
# end
#
# The Person model should in turn include AuthenticatedModel, so that it provides the
# necessary methods to deal with this authentication module
#
# class Person
#   include AuthenticatedModel
#   ...
# end
#

module AuthenticationControl

  # Inclusion hook to make #current_user and #logged_in?
  # available as ActionView helper methods.
  def self.included(base)
    base.send :helper_method, :current_user, :logged_in?
  end

  protected

  def auth_model_class
    raise "including AuthenticationControl requires the class to define an instance method called #auth_model_class"
  end

  def session_auth_key
    raise "including AuthenticationControl requires the class to define an instance method called #session_auth_key"
  end

  def session_location_store_key
    raise "including AuthenticationControl requires the class to define an instance method called #session_location_store_key"
  end

  # override in controller if needed
  def single_device_sessions
    [ 'staging', 'production' ].include?(Rails.environment)
  end

  # Returns true or false if the user is logged in.
  # Preloads @current_user with the user instance if they're logged in.
  def logged_in?
    result = current_user != :false && current_user.is_a?(auth_model_class)
    # if we have a valid current_user and we're not in development env, check session id
    if single_device_sessions
      result = result && (current_user.current_session_id == session.id.to_s)
    end
    result
  end

  # Accesses the current user from the session.
  def current_user
    @current_user ||= begin
      u = session[session_auth_key] && auth_model_class.find_by_id(session[session_auth_key])
      if u.is_a?(auth_model_class) && single_device_sessions
        u.current_session_id == session.id ? u : :false
      end
      u.nil? ? :false : u
    end
  end

  # Store the given user in the session.
  def current_user=(new_user)
    setup_session
    session[session_auth_key] = (new_user.nil? || new_user.is_a?(Symbol) || !new_user.is_a?(auth_model_class)) ? nil : new_user.id
    @current_user = new_user
    @current_user.update(current_session_id: session.id) if @current_user.is_a?(auth_model_class)
    @current_user
  end

  def setup_session
    if (ts = session['created_at']).is_a?(Time)
      if ts < Time.now - 60.minutes
        # restore the URL value to return to after login before we reset the session completely
        save_stored_location = session[session_location_store_key]
        reset_session # assign a new session id
        # restore the URL value to return to after login, but only is login was successful
        session[session_location_store_key] = save_stored_location
      end
    end
    session['created_at'] = Time.now
  end

  # Check if the user is authorized.
  #
  # Override this method in your controllers if you want to restrict access
  # to only a few actions or if you want to check if the user
  # has the correct rights.
  #
  # Example:
  #
  #  # only allow nonbobs
  #  def authorize?
  #    current_user.login != "bob"
  #  end
  def authorized?
    true
  end

  # Filter method to enforce a login requirement.
  #
  # To require logins for all actions, use this in your controllers:
  #
  #   before_action :require_login
  #
  # To require logins for specific actions, use this in your controllers:
  #
  #   before_action :require_login, :only => [ :edit, :update ]
  #
  # To skip this in a subclassed controller:
  #
  #   skip_before_action :require_login
  #
  def require_login
    logged_in? && authorized? ? true : access_denied
  end

  # Redirect as appropriate when an access request fails.
  #
  # The default action is to redirect to the login screen.
  #
  # Override this method in your controllers if you want to have special
  # behavior in case the user is not authorized
  # to access the requested action.  For example, a popup window might
  # simply close itself.
  def access_denied
    respond_to do |accepts|
      accepts.html do
        render plain: "Couldn’t authenticate you", status: :unauthorized
      end
    end
    false
  end

  # Store the URI of the current request in the session.
  #
  # We can return to this location by calling #redirect_back_or_default.
  # any controller using this method must also define a method named #session_location_store_key
  # that returns the key in the session Hash where the current_location should be stored
  def store_location(url = nil)
    session[session_location_store_key] = url || request.fullpath
  end

  # Redirect to the URI stored by the most recent store_location call or
  # to the passed default.
  def redirect_back_or_default(default)
    redirect_to(session[session_location_store_key] || default)
    session.delete(session_location_store_key)
  end

end
