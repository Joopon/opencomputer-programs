local item_record = {}

-- item: table returned from inventory_controller.getStackInInternalSlot()
function item_record.new_item_record(item, item_column, item_row, item_amount)
    return {
        item = item,
        chest_location = {
            column = item_column,
            row = item_row
        },
        amount = item_amount
    }
end

-- item: table returned from inventory_controller.getStackInInternalSlot()
function item_record.get_id(item)
    return item.name + tostring(item.damage)
end

return item_record