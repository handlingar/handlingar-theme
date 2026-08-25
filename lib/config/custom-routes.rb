# -*- encoding : utf-8 -*-
# Here you can override or add to the pages in the core website

Rails.application.routes.draw do
  get '/help/terms' => 'help#terms', :as => 'help_terms'

  # Core only exposes POST /profile/sign_up. GET is the dedicated create-account page.
  get '/profile/sign_up' => 'user#signup_form'

end
