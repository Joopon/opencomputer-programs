local storage_messages = {}

-- message types
storage_messages.ITEM_COLLECT_REQUEST = "storage_messages_item_collect_request"
storage_messages.ITEM_COLLECT_RESPONSE = "storage_messages_item_collect_response"

function storage_messages.new_item_collect_request(item_record, num_items)
    return {
        item_record = item_record,
        number_of_items = num_items
    }
end
function storage_messages.check_item_collect_request(message)
    return not (message.item_record == nil or message.number_of_items == nil or message.number_of_items <= 0)
end

function storage_messages.new_item_collect_response(item_record, num_collected)
    return {
        item_record = item_record,
        number_collected = num_collected
    }
end
function storage_messages.check_item_collect_response(message)
    return not(message.item_record == nil or message.number_collected == nil or message.number_collected < 0)
end

return storage_messages