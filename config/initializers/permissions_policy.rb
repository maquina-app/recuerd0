# Be sure to restart your server when you modify this file.

# Permissions Policy — deny access to powerful browser APIs this app never uses.
# See https://guides.rubyonrails.org/configuring.html#configuring-permissions-policy
Rails.application.config.permissions_policy do |policy|
  policy.camera :none
  policy.gyroscope :none
  policy.microphone :none
  policy.usb :none
  policy.fullscreen :self
  policy.payment :none
  policy.geolocation :none
end
