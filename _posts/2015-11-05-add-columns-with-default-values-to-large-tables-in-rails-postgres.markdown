---
layout:       post
title:        Adding columns with default values to really large tables in Postgres + Rails
author:       Sai Wong
summary:
image:        http://res.cloudinary.com/wework/image/upload/s--GnhXQxhq--/c_scale,q_jpegmini:1,w_1000/v1445269362/engineering/shutterstock_262325693.jpg
categories:   data
---

We had a fairly simple task of adding a couple of columns to a table for our
Rails app. This is normally a straight forward operation and a boring task at
best but for us, the fun only just started. The table in question was a fairly
large table with lots of reads on it and in the spirit of no down time, this
is the adventure we had.

## TL:DR;

Jump straight to the [solution](#attempt-3)!

## The Task
- Add two columns to the notifications table
- Both columns have default values
- Table has 2.2 MM rows!

## Attempt #1
```ruby
class AddPhoneFlagsToNotifications < ActiveRecord::Migration
  def change
    add_column :notifications, :text_message, :boolean, default: false
    add_column :notifications, :call_phone, :boolean, default: false
  end
end
```

### Problem
- Migration takes hours!
- The notifications table is locked
- Entire application grinds to a halt

### Reason
- Column creation with default values causes all rows to be touched at the same time
- Updates are a slow operation in Postgres since it has to guarantee consistency
- That guarantee results in whole table locking

### Solution
- Postgres can create null columns extremely fast! Even on a huge table!
- We can split the work to two tasks, creating the columns and populating the default value

## Attempt #2

```ruby
class AddPhoneFlagsToNotifications < ActiveRecord::Migration
  def change
    add_column :notifications, :text_message, :boolean
    add_column :notifications, :call_phone, :boolean

    execute <<-SQL
      ALTER TABLE notifications
        ALTER COLUMN text_message SET DEFAULT false,
        ALTER COLUMN call_phone SET DEFAULT false
    SQL

    last_id = Notification.last.id
    batch_size = 10000
    (0..last_id).step(batch_size).each do |from_id|
      to_id = from_id + batch_size
      execute <<-SQL
        UPDATE notifications
          SET
            text_message = false,
            call_phone = false
          WHERE id BETWEEN #{from_id} AND #{to_id}
      SQL
    end
  end
end
```

### Problem
- Migration takes hours!
- The notifications table is still locked!
- Entire application grinds to a halt

### Reason
- Rails migration tasks are always wrapped in a transaction to allow for rollbacks
- The column adds AND the row updates are in one gigantic transaction!
- Transactions guarantee consistency
- That guarantee results in whole table locking again!

### Solution
- You can disable the transaction handle in Rails migration by calling “disable_ddl_transaction!” in your migration task
- But you have to handle transactions on your own
- We can then run each step in its own transaction
- Add our own error handling to rollback operation

## Attempt #3

```ruby
class AddPhoneFlagsToNotifications < ActiveRecord::Migration
  disable_ddl_transaction!

  def up
    ActiveRecord::Base.transaction do
      add_column :notifications, :text_message, :boolean, default: nil
      add_column :notifications, :call_phone, :boolean, default: nil

      sql = <<-SQL
        ALTER TABLE notifications
          ALTER COLUMN text_message SET DEFAULT false,
          ALTER COLUMN call_phone SET DEFAULT false
      SQL
      execute(sql)
    end


    last_id = Notification.last.id
    batch_size = 10000
    (0..last_id).step(batch_size).each do |from_id|
      to_id = from_id + batch_size
      ActiveRecord::Base.transaction do
        execute <<-SQL
          UPDATE notifications
            SET
              text_message = false,
              call_phone = false
            WHERE id BETWEEN #{from_id} AND #{to_id}
        SQL
      end
    end

    rescue => e
      # roll back our work
      down
      raise e
  end
end
```

### Result
- Migration takes hours!
- There is no table locking
- Application is slower due to all the writes to notifications table
- Nothing grinds to a halt

## Takeaways
- Always be mindful of the number of rows affected in the migration
- Be mindful of the transaction size
- Leverage Postgres features

### Possible alternate solution
- Handle NULL case in code to treat as the desired default value
  - Clean solution and quick turn around but required us to muck up the model to abstract out that case. Give that we may or may not have complete control over how that those values are extracted from the model, this may turn into lots of defensive code.
- Add view in database to do mapping for us
  - Very clean solution though this would require us to maintain both the schema and the view whenever we do schema changes on to that table. Though we don't do changes on the schema often on this table, the extra maintance overhead was deemed not worth the value.
- Add trigger to only update rows that are actively queried
  - Also very clean solution though it came down to data integrity and since our data eventually gets slurped up by our data team, having a sane state on our data was highest priority. This meant that having a NULL state on a Boolean was not desired. Ultimately, we could of added the trigger to handle any current requests and just made the migration run slowly to backfill lesser accessed rows. Since we were able to run the entire migration within a night, we decided it wasn't worth the additional hassle.

