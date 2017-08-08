defmodule EmqEsStorage.Shared do
  require Record
  import Record, only: [defrecord: 2, extract: 2]
  defrecord :mqtt_message, extract(:mqtt_message, from_lib: "emqttd/include/emqttd.hrl")
end
