require 'nutella_lib'
require 'json'

# Parse command line arguments
broker, app_id, run_id = nutella.parse_args ARGV
# Extract the component_id
component_id = nutella.extract_component_id
# Initialize nutella
nutella.init(broker, app_id, run_id, component_id)

puts 'Initializing RoomCast...'

# Open the database
configs_db = nutella.persist.get_json_object_store('configs')
channels_db = nutella.persist.get_json_object_store('channels')
channelsData_db = nutella.persist.get_json_object_store('channels-data')

nutella.net.subscribe('configs/update', lambda do |message, from|

                                        new_configs = message

                                        puts 'configs/update:'
                                        puts new_configs

                                        # Update
                                        if new_configs != nil
                                          configs_db['configs'] = new_configs
                                        end

                                        puts 'Updated DB'

                                        # Notify Update

                                        # Notify change of all configs
                                        publish_configs_update(new_configs)

                                        # Notify possible change of current config
                                        configs = configs_db['configs']
                                        id = '%d' % configs_db['currentConfig']
                                        config = configs[id]
                                        publish_mapping_update(config['mapping'])

                                      end)

nutella.net.handle_requests('configs/retrieve', lambda do |request, from|
                                                puts 'request: ' + request
                                                reply = {}
                                                if request == {}
                                                  reply
                                                elsif request == 'all'
                                                  reply = configs_db['configs']
                                                  puts reply
                                                  reply
                                                end
                                              end)

# 'mapping' is the current running configuration
nutella.net.handle_requests('mapping/retrieve', lambda do |request, from|
                                                puts 'request: ' + request
                                                reply = {}
                                                if request == {}
                                                  reply
                                                elsif request == 'all'
                                                  configs = configs_db['configs']
                                                  id = '%d' % configs_db['currentConfig']
                                                  config = configs[id]
                                                  reply = config['mapping']
                                                  puts reply
                                                  reply
                                                end
                                              end)

nutella.net.subscribe('currentConfig/update', lambda do |message, from|

                                              new_config = message
                                              puts 'currentConfig/update:'
                                              puts new_config

                                              # Update
                                              if new_config != nil
                                                configs_db['currentConfig'] = new_config
                                              end

                                              puts 'Updated DB'

                                              # Notify Update
                                              publish_current_config_update(new_config)

                                            end)

# Reacts to updates to config id by publishing the updated mapping
nutella.net.subscribe('currentConfig/updated', lambda do |message, from|
                                               begin
                                                 configs = configs_db['configs']
                                                 id = '%d' % configs_db['currentConfig']
                                                 config = configs[id]
                                                 publish_switch_config(config['mapping'])
                                               rescue => exception
                                                 puts exception
                                                 puts exception.backtrace
                                                 raise exception
                                               end

                                             end)

nutella.net.handle_requests('currentConfig/retrieve', lambda do |request, from|
                                                      puts 'request: ' + request
                                                      reply = configs_db['currentConfig']
                                                      puts reply
                                                      reply
                                                    end)

nutella.net.subscribe('channels/update', lambda do |message, from|

                                         new_channels = message
                                         # Update
                                         if new_channels != nil
                                           channels_db['channels'] = new_channels
                                         end

                                         # Notify Update
                                         publish_channels_update(new_channels)

                                       end)

nutella.net.handle_requests('channels/retrieve', lambda do |request, from|
                                                 reply = {}
                                                 if request == {}
                                                   reply
                                                 elsif request == 'all'
                                                   reply = channels_db['channels']
                                                   puts reply
                                                   reply
                                                 end
                                               end)

nutella.net.subscribe('channel/storeImage', lambda do |message, from|

                                            puts 'channel/storeImage:'
                                            puts message
                                            puts message['id']

                                            begin

                                              # Update
                                              if message != nil
                                                db = channelsData_db['images']
                                                id = '%d' % message['id']
                                                db[id] = []
                                                db[id] = message['data']
                                              end

                                            rescue => exception

                                              puts exception
                                              puts exception.backtrace
                                              raise exception
                                            end

                                            puts 'Stored image'

                                            # Notify Update
                                            # managed at the end by channels update

                                          end)

nutella.net.handle_requests('channels/retrieveImages', lambda do |request, from|
                                                       reply = {}
                                                       if request == {}
                                                         reply
                                                       elsif request == 'all'
                                                         reply = channelsData_db['images']
                                                         puts reply
                                                         reply
                                                       end
                                                     end)

def publish_configs_update(configs)
  nutella.net.publish('configs/updated', configs)
  puts 'Sent configs/updated'
end

# Sends the update config id
def publish_current_config_update(config_id)
  nutella.net.publish('currentConfig/updated', config_id)
  puts 'Sent currentConfig/updated'
end

# Sends the whole new current configuration
def publish_switch_config(mapping)
  nutella.net.publish('currentConfig/switched', mapping)
  puts 'Sent currentConfig/switched'
end

# Sends the current config (mapping), which might have been updated
def publish_mapping_update(mapping)
  nutella.net.publish('mapping/updated', mapping)
  puts 'Sent mapping/updated'
end

def publish_channels_update(channels)
  nutella.net.publish('channels/updated', channels)
  puts 'Sent channels/updated'
end

puts 'Initialization complete.'

# Just sit there waiting for messages to come
nutella.net.listen