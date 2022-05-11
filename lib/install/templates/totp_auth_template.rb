# frozen_string_literal: true

module TotpAuth
  # this is the RFC default
  DEFAULT_INTERVAL = 30
  private_constant :DEFAULT_INTERVAL
  DEFAULT_DIGITS = 6

  def self.included(base)
    base.extend(ClassMethods)

    base.store(:totp_data,
               accessors: %i[
                 totp_secret_key
                 totp_new_secret_key
                 totp_method
                 totp_cookie
                 totp_cookie_expiration
               ],
               coder: JSON
              )
    base.before_create(:setup_totp)

    base.attr_reader(:new_totp_code)

    base.validates_inclusion_of(:totp_method, in: %w[app email none], allow_nil: true)

    base.before_save(:update_totp_values)
  end

  module ClassMethods
    def totp_issuer_name
      raise StandardError.new("TotpAuth module is included in a class which does not define a class method named `totp_issuer_name`")
    end

    # length is byte size. Once encoded a 10-byte secret will have a String length orf 16.
    def totp_random_secret(length = 10)
      ROTP::Base32.random(length)
    end

    def attributes_protected_by_default
      super + %i[totp_secret_key new_totp_code]
    end
  end

  def setup_totp
    totp_regenerate_secret if totp_secret_key.blank?
  end

  def update_totp_values
    return unless totp_method.nil? || totp_method == 'none'

    self.totp_secret_key = nil
    self.totp_new_secret_key = nil
    self.totp_cookie = nil
    self.totp_cookie_expiration = nil
  end

  def update_totp_cookie
    next_expiration = Time.zone.now + 30.days
    update!(totp_cookie_expiration: next_expiration,
            totp_cookie: Digest::SHA1.hexdigest("#{id}--#{next_expiration}")
           )
    totp_cookie
  end

  def totp_cookie_valid_on_device?(cookie_value)
    cookie_value == totp_cookie && !totp_cookie_expired?
  end

  def totp_cookie_expired?
    exp = totp_cookie_expiration.try(:to_time) || Time.zone.now - 1.day
    totp_cookie.blank? || exp < Time.zone.now
  end

  def totp_regenerate_secret
    self.totp_secret_key = self.class.totp_random_secret
  end

  def totp_generate_new_secret(force: false)
    self.totp_new_secret_key = self.class.totp_random_secret if force || totp_new_secret_key.blank?
  end

  def authenticate_totp(code)
    # return true if backup_codes_enabled? && authenticate_backup_code(code)
    drift_behind = totp_method == 'email' ? 120 : 0
    totp_instance.verify(code.to_s, drift_behind: drift_behind)
  end

  def authenticate_new_totp(code)
    # return true if backup_codes_enabled? && authenticate_backup_code(code)
    drift_behind = totp_method == 'email' ? 120 : 0
    totp_new_secret_instance.verify(code.to_s, drift_behind: drift_behind)
  end

  def totp_code
    # time = options.is_a?(Hash) ? options.fetch(:time, Time.now) : options
    totp_instance.now
  end

  def totp_provisioning_uri(account = nil)
    account ||= email if respond_to?(:email)
    account ||= ''
    totp_instance.provisioning_uri(account)
  end

  def totp_new_provisioning_uri(account = nil)
    account ||= email if respond_to?(:email)
    account ||= ''
    totp_new_secret_instance.provisioning_uri(account)
  end

  def totp_disabled
    totp_method.nil? || totp_method == 'none'
  end
  alias totp_disabled? totp_disabled

  def totp_by_email
    totp_method == 'email'
  end
  alias totp_by_email? totp_by_email

  def totp_by_app
    totp_method == 'app'
  end
  alias totp_by_app? totp_by_app

  def activate_totp(method, commit_new_secret: true)
    attrs = { totp_method: method }
    if commit_new_secret
      attrs[:totp_secret_key] = totp_new_secret_key
      attrs[:totp_new_secret_key] = nil
    end
    attrs[:totp_secret_key] = self.class.totp_random_secret if method == 'email' && totp_secret_key.blank?
    update!(attrs)
  end

  def totp_issuer_name
    self.class.totp_issuer_name
  end

  protected

  def totp_instance
    ROTP::TOTP
      .new(totp_secret_key, { issuer: self.class.totp_issuer_name, interval: DEFAULT_INTERVAL, digits: DEFAULT_DIGITS })
  end

  def totp_new_secret_instance
    ROTP::TOTP
      .new(totp_new_secret_key, { issuer: self.class.totp_issuer_name, interval: DEFAULT_INTERVAL, digits: DEFAULT_DIGITS })
  end
end
