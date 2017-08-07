defmodule EmqEsStorage.MqttMessage do
  require Record
  import Record, only: [extract: 2]
  defstruct extract(:mqtt_message, from_lib: "emqttd/include/emqttd.hrl")
end
