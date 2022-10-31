module BulletTrain
  module Routes
    module MapperExtensions
      def current_namespaces
        @current_namespaces ||= []
      end
    
      def current_models
        @current_models ||= []
      end
    
      def namespaces(namespaces, &block)
        if namespaces.any?
          current_namespaces << {namespace_name: namespaces.shift, pending_blocks: []}
          namespace current_namespaces.last[:namespace_name], &block
          current_namespaces.pop[:pending_blocks].each do |block|
            block.call
          end
        else
          yield block
        end
      end
    
      def deduplicate_namespaces(namespace_names)
        still_needed = []
    
        while namespace_names.any?
          if current_namespaces.last(namespace_names.count).map { |namespace| namespace[:namespace_name] } == namespace_names
            return still_needed
          else
            still_needed.unshift namespace_names.pop
          end
        end
    
        still_needed
      end
    
      def namespaces_to_eject(namespace_names)
        return [] unless current_models[-2]
    
        # E.g. `Common::Projects::Deliverable` and `Common::Objective` should be 1.
        # E.g. `Common::Projects::Deliverable` and `Common::Other::Objective` should be 1.
        working_namespace_names = namespace_names.dup
        parent_namespace_names = current_models[-2][:model_name][0..-2]
    
        while parent_namespace_names.any? && working_namespace_names.first == parent_namespace_names.first
          working_namespace_names.shift
          parent_namespace_names.shift
        end
    
        parent_namespace_names
      end
    
      def model(*parameters, &block)
        namespace_names = parameters[0].underscore.split("/")
        current_models << {model_name: namespace_names.dup, pending_blocks: []}
        model_name = namespace_names.pop
    
        original_namespace_names = namespace_names.dup
        namespace_names = deduplicate_namespaces(namespace_names)
    
        # E.g. `Project` vs. `Projects::Deliverable`.
        if current_models[-2] && namespace_names.first == current_models[-2][:model_name].last.pluralize
          current_namespaces << {namespace_name: namespace_names.shift, pending_blocks: []}
    
          scope module: current_namespaces.last[:namespace_name] do
            namespaces namespace_names do
              # TODO We need people to be able to specify more than just [:index, :new, :create] for collection actions.
              resources model_name.pluralize.to_sym, (parameters[1] || {}).merge(only: [:index, :new, :create]), &block
            end
          end
    
          current_namespaces_last = current_namespaces.last[:namespace_name]
    
          current_models.last[:pending_blocks] << proc do
            # This needs to be registered to run _after_ we leave the `resources` block of the parent.
            namespace current_namespaces_last.to_sym do
              resources model_name.pluralize.to_sym, (parameters[1] || {}).merge(except: [:index, :new, :create]), &block
            end
          end
    
          current_namespaces.pop[:pending_blocks].each do |block|
            block.call
          end
        # E.g. `Projects::Deliverable` and `Objective`
        elsif (ejection_count = namespaces_to_eject(original_namespace_names).count) > 0
          resource_symbol = current_models[-2][:model_name][((ejection_count + 1) * -1)..-1].join("_").to_sym
          resource_path = current_models[-2][:model_name][((ejection_count + 1) * -1)..-1].join("/")
    
          current_namespaces[ejection_count * -1][:pending_blocks] << proc do
            resources resource_symbol, path: resource_path do
              namespaces namespace_names do
                resources model_name.pluralize.to_sym, parameters[1] || {}, &block
              end
            end
          end
        else
          namespaces namespace_names do
            resources model_name.pluralize.to_sym, parameters[1] || {}, &block
          end
        end
    
        current_models.pop[:pending_blocks].each do |block|
          block.call
        end
      end
    end
  end
end