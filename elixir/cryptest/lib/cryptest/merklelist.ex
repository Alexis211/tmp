defmodule Cryptest.MerkleList do
  use GenServer

  def start_link([cmp, name: name]) do
    GenServer.start_link(__MODULE__, cmp, [name: name])
  end

  defp term_hash(term) do
    :crypto.hash(:sha256, (:erlang.term_to_binary term))
  end

  @doc """
    Initialize a Merkle List storage.
    `cmp` is a function that compares stored items and provides a total order.

    It must return:
      - `:after` if the first argument is more recent
      - `:duplicate` if the two items are the same
      - `:before` if the first argument is older
  """
  def init(cmp) do
    root_item = :root
    root_hash = term_hash root_item
    state = %{
              root:  root_hash,
              top:   root_hash,
              cmp:   cmp,
              store: %{ root_hash => root_item }
            }
    {:ok, state}
  end

  defp state_push(item, state) do
    new_item = {item, state.top}
    new_item_hash = term_hash new_item
    new_store = Map.put(state.store, new_item_hash, new_item)
    %{ state | :top => new_item_hash, :store => new_store }
  end

  defp state_pop(state) do
    if state.top == state.root do
      :error
    else
      {item, next} = Map.get(state.store, state.top)
      new_store = Map.delete(state.store, state.top)
      new_state = %{ state | :top => next, :store => new_store }
      {:ok, item, new_state}
    end
  end

  defp insert_many(state, [], _callback) do
    state
  end

  defp insert_many(state, [item | rest], callback) do
    case state_pop(state) do
      :error ->
        new_state = state_push(item, insert_many(state, rest, callback))
        callback.(item)
        new_state
      {:ok, front, state_rest} ->
        case state.cmp.(item, front) do
          :after ->
            new_state = state_push(item, insert_many(state, rest, callback))
            callback.(item)
            new_state
          :duplicate -> insert_many(state, rest, callback)
          :before -> state_push(front, insert_many(state_rest, [item | rest], callback))
        end
    end
  end

  def handle_cast({:insert, item}, state) do
    handle_cast({:insert_many, [item]}, state)
  end

  def handle_cast({:insert_many, items}, state) do
    handle_cast({:insert_many, items, fn _ -> nil end}, state)
  end

  def handle_cast({:insert_many, items, callback}, state) do
    items_sorted = Enum.sort(items, fn (x, y) -> state.cmp.(x, y) == :after end)
    new_state = insert_many(state, items_sorted, callback)
    {:noreply, new_state}
  end

  def handle_call({:read, qbegin, qlimit}, _from, state) do
    begin = qbegin || state.top
    limit = qlimit || 20
    items = get_items_list(state, begin, limit)
    {:reply, items, state}
  end

  def handle_call(:top, _from, state) do
    {:reply, state.top, state}
  end

  def handle_call(:root, _from, state) do
    {:reply, state.root, state}
  end

  def handle_call({:has, hash}, _from, state) do
    {:reply, Map.has_key?(state.store, hash), state}
  end

  defp get_items_list(state, begin, limit) do
    case limit do
      0 -> {:ok, [], begin}
      _ ->
        case Map.fetch(state.store, begin) do
          {:ok, :root} ->
            {:ok, [], nil }
          {:ok, {item, next}} ->
            case get_items_list(state, next, limit - 1) do
              {:ok, rest, past} ->
                {:ok, [ item | rest ], past }
              {:error, reason} -> {:error, reason}
            end
          :error -> {:error, begin}
        end
    end
  end

  @doc """
    Compare function for timestamped strings
  """
  def cmp_ts_str({ts1, str1}, {ts2, str2}) do
    cond do
      ts1 > ts2 -> :after
      ts1 < ts2 -> :before
      str1 == str2 -> :duplicate
      str1 > str2 -> :after
      str1 < str2 -> :before
    end
  end
end
