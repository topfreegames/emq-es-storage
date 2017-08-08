defmodule EmqEsStorage.Redis do
  def command(command) do
    {:ok, result} = Redix.command(:"emq_es_storage_redix_#{random_index()}", command)
    result
  end

  defp random_index do
    rem(System.unique_integer([:positive]), 5)
  end
end
