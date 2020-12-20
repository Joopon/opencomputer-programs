local queue = {}

-- size > 1
function queue.new(size)
    return {
        first = 0,
        last = 0,
        size = size
    }
end

-- returns: true if success, otherwise false (queue is already full)
function queue.push(fifo, elem)
    local new_last = (fifo.last + 1) % (fifo.size+1)
    if new_last == fifo.first then
        -- queue is full
        return false
    end
    fifo[fifo.last] = elem
    fifo.last = new_last
    return true
end

-- returns: first element in queue, nil if queue is empty
function queue.pop(fifo)
    if fifo.first == fifo.last then
        -- queue is empty
        return nil
    end
    local elem = fifo[fifo.first]
    fifo[fifo.first]=nil
    fifo.first = (fifo.first+1) % (fifo.size+1)
    return elem
end

return queue

