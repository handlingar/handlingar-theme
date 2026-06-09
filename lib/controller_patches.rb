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
  end

  UserController.class_eval do
    module SignupNameValidation
      def signup
        name = params.dig(:user_signup, :name).to_s
        if name.present?
          allowed_chars = Regexp.new('^[a-zA-Z0-9\-—_. \',\(\)àááâÁÂçÇéêèëÉÈğïíîöôÖüÿ@&]+$')
          if !name.match?(allowed_chars) ||
             name.match?(/^[a-zA-Z0-9]{10}$/) ||
             name.match?(/^[a-zA-Z0-9]{16,24}$/) ||
             name.match(/telegra\.ph\//) ||
             name.match(/graph\.org\//)
            flash.now[:error] = _('There was a problem with your submission. Please try again.')
            render action: 'sign'
            return
          end
        end
        super
      end
    end
    prepend SignupNameValidation
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
