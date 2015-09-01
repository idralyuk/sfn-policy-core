
#
# default_state
#
# Provides a helper method used to set default state attributes without
# overriding existing states.
#
SfnRegistry.register(:default_state) do |_config|
  _config.each do |key, value|
    if value.nil? 
      _arg_state.delete(key)
    elsif state!(key).nil?
      set_state!(key => value)
    end
  end
end

#
# default_config
#
# Provides a helper method used to store configuration attributes
# within a state!(key) hash.
#
SfnRegistry.register(:default_config) do |_name, _config|
  _current_state = state!(_name) || {}

  _config.each do |key, value|
    next if _current_state.key?(key) and not
            _current_state[key].nil? and not
            (_current_state[key].empty? rescue false)
    _current_state[key] = value
  end

  set_state!(_name => _current_state)
end

SfnRegistry.register(:apply_config) do |_name, _config|
  _current_state = state!(_name) || {}

  _config.each do |key, value|
    _current_state[key] = value
  end

  _current_state.delete_if {|k,v| v.nil? }

  set_state!(_name => _current_state)
end
