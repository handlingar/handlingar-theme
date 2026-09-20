# If defined, ALAVETELI_TEST_THEME will be loaded in
# config/initializers/theme_loader
ALAVETELI_TEST_THEME = 'handlingar-theme' unless defined?(ALAVETELI_TEST_THEME)

require File.expand_path('../../../../spec/spec_helper', __dir__)
