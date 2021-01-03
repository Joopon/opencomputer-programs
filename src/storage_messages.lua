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

return storage_messages