
#
# scaling_group
#
# Creates an autoscaling group as well as it's scaling policies and alarms.
#
SparkleFormation.dynamic(:scaling_group) do |_name, _config = {}|
  _config = {} if _config.nil?

  #
  # Extract nested non-standard hashes
  #
  nested_dynamics = %w(
    metadata
    notifications
    creation_policy
    update_policy
    deletion_policy
    scaling_policies
  )

  nested_configs = {}
  nested_configs[:scaling_group] = _config
  nested_dynamics.each do |key|
    nested_configs[key.to_sym] = _config.delete(key.to_sym) || {}
  end

  #
  # Create the autoscaling group nested resources
  #
  nested_resources = {}
  nested_configs.each do |key, config|
    next if config == false
    #next if (config.is_a?(Hash) or config.is_a?(Array)) and config.empty?
    key = key.to_sym

    dynamic_name =  case key
                    when :metadata        then :metadata
                    when :notifications   then :scaling_notifications
                    when :scaling_group   then :scaling_basic_group
                    when :creation_policy then :scaling_creation_policy
                    when :update_policy   then :scaling_update_policy
                    when :deletion_policy then :scaling_deletion_policy
                    when :scaling_policies then :scaling_default_policies
                    else raise 'Unknown dynamic: ' << "#{key}"
                    end

    nested_resources[key] = dynamic! dynamic_name, _name, config
  end

  #
  # Return the scaling_group resource
  #
  nested_resources[:scaling_group]
end

#
# scaling_notifications
#
# Provides SNS topic notifications upon a stack's scaling events
#
SparkleFormation.dynamic(:scaling_notifications) do |_name, _config = {}|
  _config = {} if _config.nil?

  resources.set!(_name) do
    registry! :default_config, :notifications,
      types: %w(
        autoscaling:EC2_INSTANCE_LAUNCH
        autoscaling:EC2_INSTANCE_TERMINATE
      ),
      topic: ref!(:vpc_scaling_sns_id)

    registry! :apply_config, :notifications, 
      _config

    properties do
      notification_configurations array!(
        { 
          NotificationTypes: state!(:notifications)[:types],
          TopicARN: state!(:notifications)[:topic]
        }
      )
    end
  end
end

#
# scaling_basic_group
#
# Creates a basic autoscaling group which is configured to depend on a number
# of standard parameters which are loaded and defined in registries.
#
SparkleFormation.dynamic(:scaling_basic_group) do |_name, _config = {}|
  _config = {} if _config.nil?

  #
  # Load required parameters
  #
  registry! :ami_params
  registry! :instance_params
  registry! :scaling_params

  #
  # Create an output referencing the autoscaling group
  #
  outputs.set!("#{_name}_id") do
    value ref!(_name)
  end

  #
  # Create the autoscaling group resource
  #
  resources.set!(_name) do
    type "AWS::AutoScaling::AutoScalingGroup"
    set_state!(auto_scaling: true)
    set_state!(_config.delete(:state) || {})

    registry! :resource_config, :config, _config,
      launch_configuration_name:  ref!(:launch_config),
      health_check_grace_period:  ref!(:scaling_grace_period),
      health_check_type:          "ELB",
      availability_zones:         ref!(:vpc_availability_zones),
      VPC_zone_identifier:        registry!(:context_subnets),
      max_size:                   ref!(:scaling_nodes_max),
      min_size:                   ref!(:scaling_nodes_min),
      desired_capacity:           ref!(:scaling_nodes_desired),
      load_balancer_names:        array!(ref!(:load_balancer_id))

    registry! :resource_properties, :config
  end
end

