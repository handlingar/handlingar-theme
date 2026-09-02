# -*- encoding : utf-8 -*-
# Add a callback - to be executed before each request in development,
# and at startup in production - to patch existing app classes.
# Doing so in init/environment.rb wouldn't work in development, since
# classes are reloaded, but initialization is not run each time.
# See http://stackoverflow.com/questions/7072758/plugin-not-reloading-in-development-mode
#
Rails.configuration.to_prepare do
  HelpController.class_eval do
    def terms; end
    def learn; end
  end

  UserController.class_eval do
    before_action :work_out_post_redirect, only: [:signup_form]
    before_action :set_request_from_foreign_country, only: [:signup_form]
    before_action :set_in_pro_area, only: [:signup_form]

    def signup_form
      if @user
        redirect_path = params.fetch(:r) { frontpage_path }
        redirect_to SafeRedirect.new(redirect_path).path
        return
      end

      render template: 'user/sign_up'
    end
  end

  ActionView::Base.prepend(HandlingarCaptcha::ViewMethods)
  ActionController::Base.prepend(HandlingarCaptcha::ControllerMethods)

  # /pro/pricing calls Stripe for plan amounts. Staging may have the route on
  # without valid Stripe keys — show the page instead of a 500.
  if defined?(AlaveteliPro::PlansController)
    AlaveteliPro::PlansController.class_eval do
      def index
        @pro_site_name = pro_site_name
        @prices = Array(AlaveteliPro::Price.list).compact
      rescue Stripe::StripeError, NoMethodError
        @prices = []
      end
    end
  end
end
  # Example adding an instance variable to the frontpage controller
  # GeneralController.class_eval do
  #   def mycontroller
  #     @say_something = "Greetings friend"
  #   end
  # end
  # Example adding a new action to an existing controller
  # HelpController.class_eval do
  #   def help_out
  #   end
  # end
  # Rails.application.routes.draw do
  # brand new controller example
  # get '/mycontroller' => 'general#mycontroller'
  # Additional help page example
  # get '/help/terms' => 'help#terms'
  # end
# end
