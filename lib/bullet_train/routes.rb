require "bullet_train/routes/version"
require "bullet_train/routes/railtie"
require "bullet_train/routes/mapper_extensions"

module BulletTrain
  module Routes
  end
end

ActiveSupport.on_load(:action_controller) do 
  ActionDispatch::Routing::Mapper.include(BulletTrain::Routes::MapperExtensions)
end