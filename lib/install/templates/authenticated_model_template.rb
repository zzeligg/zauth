# frozen_string_literal: true

# == AuthenticatedModel module ==
#
# Declares the authentication methods for a 'User' model.
#
# Simply include this module with your User model:
#
#    class User < ApplicationRecord
#        include AuthenticatedModel
#        ....
#    end
# 
#  The model must have the following attributes (table columns):
#
#   :email                string
#   :crypted_password     string
#   :current_session_id   string (require if you use AuthenticationControl#single_device_sessions)
# 
# Your user class can be named anything you want, it does not require to be 'User'
#
#  If you require to authenticate based on a username instead of email address
#  change all the references to email attribute in this module.

require 'digest/sha1'
require 'digest/sha2'

module AuthenticatedModel

  def self.included(base)
    base.validates_presence_of(:email)
    base.validates_uniqueness_of(:email)
    base.validates_length_of(:password, within: 8..40, if: :password_required?)
    base.validates_confirmation_of(:password, if: :password_required?)
    base.before_save(:encrypt_password)
    base.extend(ClassMethods)
  end

  attr_accessor :password

  module ClassMethods
    # Authenticates a user by their email and unencrypted password.  Returns the user or nil.
    def authenticate(email, password)
      # need to get the salt
      user = find_by_email(email)
      return unless user&.authenticated?(password)

      # make sure a pending password request will not remain forever
      user.update!(password_reset_code: nil) unless user.password_reset_code.nil?
      user
    end

    # Encrypts some data with the salt.
    def encrypt(password, salt)
      Digest::SHA2.hexdigest("--#{password}--")
    end
  end

  def authenticated?(password)
    crypted_password == encrypt(password)
  end

  def password_required?
    (crypted_password.blank? || password.present? || password_reset_code.present?)
  end

  # Encrypts the password with the user salt
  def encrypt(password)
    self.class.encrypt(password, password_salt)
  end

  def encrypt_password
    return if password.blank?
    self.crypted_password = encrypt(password)
  end

  def record_login
    update!(last_login_at: Time.zone.now, login_count: login_count.to_i + 1)
  end

  #  def remember_token?
  #    remember_token_expires_at && Time.now.utc < remember_token_expires_at
  #  end
  #
  #  # These create and unset the fields required for remembering users between browser closes
  #  def remember_me
  #    remember_me_for 2.weeks
  #  end
  #
  #  def remember_me_for(time)
  #    remember_me_until time.from_now.utc
  #  end
  #
  #  # Useful place to put the login methods
  #  def remember_me_until(time)
  #    self.last_login_at = Time.now
  #    self.remember_token_expires_at = time
  #    self.remember_token = encrypt("#{email}--#{remember_token_expires_at}")
  #    save(:validate => false)
  #  end
  #
  #  def forget_me
  #    self.remember_token_expires_at = nil
  #    self.remember_token            = nil
  #    save(:validate => false)
  #  end

  def init_password
    create_random_password if password.blank? && crypted_password.blank?
  end

  def create_random_password
    self.password = self.password_confirmation = Digest::SHA2.hexdigest(Time.zone.now.to_s.chars.sort_by { rand }.join)
  end

  def create_password_reset_code(do_save: false)
    # use SHA1 to limit length of generated hash
    self.password_reset_code = Digest::SHA1.hexdigest(Time.zone.now.to_s.chars.sort_by { rand }.join)
    save!(validate: false) if do_save
  end

  def clear_password_reset_code(do_save: false)
    self.password_reset_code = nil
    save!(validate: false) if do_save
  end
end
