# Definitely change this when you deploy to production. Ours is replaced by jenkins.
# This token is used to secure sessions, we don't mind shipping with one to ease test and debug,
#  however, the stock one should never be used in production, people will be able to crack
#  session cookies.
#
# Generate a new secret with "rake secret".  Copy the output of that command and paste it
# in your secret_token.rb as the value of Discourse::Application.config.secret_token:

Discourse::Application.config.secret_token = "4c0b733eeedf5696d68546d7b95e973005b0033b419c0ee73f79755f2696bc9087e4331a147a8cce6c6ed213a6b53afcfbefd596e0b502fb9bdb2ab9d91695dc"
