local GRU = {}

function GRU.init(input_size, gru_size, num_layers)
  local inputs = {}
  for L = 1,(n+1) do
    table.insert(inputs, nn.Identity()())
  end

  function new_input_sum(insize, xv, hv)
    local i2h = nn.Linear(insize, gru_size)(xv)
    local h2h = nn.Linear(gru_size, gru_size)(hv)
    return nn.CAddTable()({i2h, h2h})
  end

  local x, input_size_L
  local outputs = {}
  for L = 1,n do

    local prev_h = inputs[L+1]
    -- the input to this layer
    if L == 1 then 
      x = OneHot(input_size)(inputs[1])
      input_size_L = input_size
    else 
      x = outputs[(L-1)] 
      if dropout > 0 then x = nn.Dropout(dropout)(x) end -- apply dropout, if any
      input_size_L = rnn_size
    end
    -- GRU tick
    -- forward the update and reset gates
    local update_gate = nn.Sigmoid()(new_input_sum(input_size_L, x, prev_h))
    local reset_gate = nn.Sigmoid()(new_input_sum(input_size_L, x, prev_h))
    -- compute candidate hidden state
    local gated_hidden = nn.CMulTable()({reset_gate, prev_h})
    local p2 = nn.Linear(rnn_size, rnn_size)(gated_hidden)
    local p1 = nn.Linear(input_size_L, rnn_size)(x)
    local hidden_candidate = nn.Tanh()(nn.CAddTable()({p1,p2}))
    -- compute new interpolated hidden state, based on the update gate
    local zh = nn.CMulTable()({update_gate, hidden_candidate})
    local zhm1 = nn.CMulTable()({nn.AddConstant(1,false)(nn.MulConstant(-1,false)(update_gate)), prev_h})
    local next_h = nn.CAddTable()({zh, zhm1})

    table.insert(outputs, next_h)
  end
-- set up the decoder
  local top_h = outputs[#outputs]
  top_h = nn.Dropout(true)(top_h)
  local pred = nn.Linear(rnn_size, input_size)(top_h)
  table.insert(outputs, pred)

  return nn.gModule(inputs, outputs)
end

return GRU