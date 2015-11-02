---
layout:       post
title:        "Expanding Redshift: Adding a sortkey and distkey"
author:       Ahmed Elsamadisi
summary:      Redshift doesn't allow a user to add or update a sort/dist key. This post will walk through a python script to go around redshift.
image:          http://image.shutterstock.com/display_pic_with_logo/83849/267703928/stock-vector--profiling-evaluation-process-of-sorting-items-according-to-their-shape-and-color-267703928.jpg
categories:   frontend
---

## Understanding the Problem

If your reading this post then you ran into the same blockage as many data engineers have when using AWS Redshift.  I assume you followed the following steps: created an instance of Redshift to house all your data for your analytics, leveraged a third party service to ELT most of your data and allowed engineers to also dump data into redshift.  Now, all data is following into Redshift and all analytics data is being accessed through Redshift.  This is working great but you begin to see degradation in speed.  You look into your initial setup and you realize that you are not leveraging key features of Redshift, the sortkey and distkey (Check out [this article](https://www.periscopedata.com/blog/double-your-redshift-performance-with-the-right-sortkeys-and-distkeys.html) to see the improvements with sortkeys/distkeys).  

## Redshift limitation

To optimize your Redshift performance you are now attempting to add sortkeys and distkeys.  Great idea but **unfortunately** Redshift doesn't allow you to add them. Reshift allows 'CREATE TABLE LIKE' and 'CREATE TABLE AS ()' but both have their own restrictions and do not solve the problem.  As many data engineers quickly realize, you need to add a layer on top of Redshift to manage these situation.  I highly recommend python for this layer. Python has many libraries to enable machine learning and data science, which your company will be grateful that you have already did the ground work for python-Redshift integration.  Finally, this blog will continue to build upon what you can do in Reshift with python (i.e. materialization, incremental materialization, automatic vacuuming, alerting etc...).

## Solution Steps
You can skip to the bottom and get the entire python script (soon WeWork will open source its entire python project above of Reshift).  However, you can scroll thorugh the different steps

- Set the current search path
- Identify the column types and defaults
- Create a new table with the same types and all the desired keys
- Insert all data from the original table
- Rename the tables
- Vacuum the old table
- Update access/Owners

### Set the current session

The first thing is that you must set the current search path to include all the schemas table keys and types.
db is a cursor from the Redshift connection.

```python
def update_search_path():
    global db

    #get all the schemas
    db.execute('''
    SELECT DISTINCT schemaname from pg_catalog.pg_tables;
    ''')
    schema_names = db.fetchall()

    # generate a search path query
    query_txt = "SET search_path to '$user', public "

    for ii in range(0,len(schema_names)):
        query_txt = query_txt +  ", " + schema_names[ii][0]

    query_txt = query_txt +";"

    #update the query
    db.execute(query_txt)
```


### Identify the column types and defaults

Once the search path is set, you can pull the details of the columns in the tables.

```python
sql_query = '''
SELECT "column", "type" , "encoding", "notnull" from pg_catalog.pg_table_def
where schemaname = '%s' and tablename = '%s';
''' % (schema_name, table_name)
db.execute(sql_query)
column_info = db.fetchall()
```

### Create a new table with the same types and all the desired keys
Using the types from the first table, we will recreate a new table with the sortkeys, distkeys and primary key.

```python    
# Grab table information
sql_query = '''
SELECT "column", "type" , "encoding", "notnull" from pg_catalog.pg_table_def
where schemaname = '%s' and tablename = '%s';
''' % (schema_name, table_name)
db.execute(sql_query)
column_info = db.fetchall()

#create the insert query
add_query='''
Insert into "%s"."%s_temp" (SELECT
''' % (schema_name, table_name)

# pulling all the new defintions
for ii in range(0, len(column_info)):
    recreate_query = recreate_query + create_row_str(column_info[ii] , primarykey, default_prime_value)

# addign the kesys
recreate_query = recreate_query + ('''
PRIMARY KEY (%s))
distkey(%s)
sortkey(%s);
''' % (primarykey, distkey, sortkey))

# User feedback
print ("Recreating the table with the approperiate keyes.... \n")
print ("executing: \n" + recreate_query)

# Executing and commiting
db.execute(recreate_query)
conn.commit()

```

This code generates the following queries :

```SQL
Create table "rooms_public"."conference_rooms_temp" (
"id" integer  not null,
"uuid" character varying(180) ,
"name" character varying(1020) ,
"capacity" integer ,
"notes" character varying(65535) ,
"floor_id" integer ,
"tags" character varying(760) ,
"created_at" timestamp without time zone ,
"updated_at" timestamp without time zone ,
"image_url" character varying(1020) ,
"specialty" boolean ,
"credit_mappings" character varying(3905)  encode lzo,
"credit_values" character varying(135) ,
"deleted_at" timestamp without time zone ,
"kisi_lock_id" character varying(1020) ,
"opening_time" character varying(40) ,
"closing_time" character varying(40) ,
"wdays_available_on" character varying(75) ,
"active_for_anywhere" boolean ,
"active_for_member" boolean ,
"open_date" date ,
"close_date" date ,
"active_for_weworker" boolean ,

  PRIMARY KEY (id))
  distkey(uuid)
  sortkey(created_at);

```



### Insert all data from the original table

Redshift allows you to insert data from a query.  Since we are recreating the type then we can trust that our insert statement will work.  

```python
#create the insert query
add_query='''
Insert into "%s"."%s_temp" (SELECT
''' % (schema_name, table_name)

# pulling all the new defintions
for ii in range(0, len(column_info)):
    add_query = add_query + (''' "%s", ''' % column_info[ii][0])

# Add the data into the new table
add_query= add_query[:-2] + ('''
 FROM "%s"."%s" );
''' % (schema_name, table_name))

print ("copying all the data to the new table .... \n")
print ("executing: \n" + add_query)

#inserting the data and commit
db.execute(add_query)
conn.commit()

```

This creates the following query:

```SQL
Insert into "rooms_public"."conference_rooms_temp" (
  SELECT
  "id",  "uuid",  "name",  "capacity",  "notes",  "floor_id",  "tags",  "created_at",  "updated_at",  "image_url",  "specialty",  "credit_mappings",  "credit_values",  "deleted_at",  "kisi_lock_id",  "opening_time",  "closing_time",  "wdays_available_on",  "active_for_anywhere",  "active_for_member",  "open_date",  "close_date",  "active_for_weworker"
 FROM "rooms_public"."conference_rooms"
);

```



### Rename your current table

Rename your current table.  **Do not delete the table until your done with the entire script.**
It is important to rename the queries and update the access at the end to allow minimal interruption through for the Redshift users.

```python

""" Renaming the tables"""
# Rename current table
change_query='''
ALTER Table "%s"."%s" rename to "%s_original";
''' % (schema_name, table_name, table_name)
print ("renaming old table.... \n")
print ("executing: \n" + change_query)
db.execute(change_query)


change_query='''
ALTER Table "%s"."%s_temp" rename to "%s";
''' % (schema_name, table_name, table_name)
print ("renaming old table....\n")
print ("executing: \n" + change_query)
db.execute(change_query)

```

This creates the following query:

```SQL
  ALTER Table "rooms_public"."conference_rooms" rename to "conference_rooms_original";
  ALTER Table "rooms_public"."conference_rooms_temp" rename to "conference_rooms";
```

### Vacuum the table

Once you added the keys, you will need to vacuum the table.

```python
print "Vacuum the table"
old_isolation_level = db_conn.isolation_level
master_conn.set_isolation_level(0)
db.execute('''vacuum "%s"."%s";''' % (schema_name, table_name))
master_conn.set_isolation_level(old_isolation_level)
```


### Update Access/Owner

Now that you created

```python
change_query='''
ALTER Table "%s"."%s" Owner to %s;
''' % (schema_name, table_name, owner)

print ("Updating the owner of the table....\n")
print ("executing: \n" + change_query)

query_text= '''
GRANT ALL ON %s IN SCHEMA %s TO GROUP insights_group;
GRANT SELECT ON %s IN SCHEMA %s TO GROUP read_only_group;
'''
conn.execute_query(query_text)
conn.commit()
```


## Solution Code
This python script will ask the creator for the primary key, defaults, sortkeys and distkeys.

``` python
#!/usr/bin/env python

'''
update_tables_keys.py

This script will update a table to add the sort-keys/distkeys.

Format of input
python update_tables_keys.py

'''
import time
import sys
import importlib
import pip

# ADD THE CONNECTION INFORMATION
HOST=
PORT =
DATABASENAME =


# Import library and if library doesn't exist it will download it
def install_and_import(import_name, import_package):

    try:
        globals()[import_name] = importlib.import_module(import_name)
    except ImportError:
        pip.main(['install', import_package])
    finally:
        globals()[import_name] = importlib.import_module(import_name)


#gets the user information and connects
def connect(args):

    global master_conn

    # Get user's login information
    if ( len(args)>1):
        db_user=args[1]
    else:
        db_user=raw_input('Please enter your username:\n')

    if ( len(args)>2):
        db_pwd=args[2]
    else:
        db_pwd=getpass.getpass('Please enter your password:\n')

    # connect to the database
    print "connecting....."
    master_conn = psycopg2.connect(host = HOST, database= DATABASENAME, user=db_user, password=db_pwd, port = PORT)
    print "connected"

# print the first column of the array of arrays in python
def print_sql_col(sql_col):

    res =[]
    print '\n'
    print '---------------------------'
    for ii in range(0, len(sql_col)):
        print(sql_col[ii][0])
        res.append(sql_col[ii][0])

    print '\n'
    return res



  def choose_from_list(list_vals, list_name, retry_count = 3):

      for ii in range(0,retry_count):
          #print the list
          for ii in range(0, len(list_vals)):
              print ( "%s -> %s" % (ii, list_vals[ii]))

          chosen_input = input( "Select an %s by typing the number associated to it. \n(Press Enter to cancel) \n" % list_name)

          if( chosen_input == ''):
              break

          try:
              return_val = list_vals[int(chosen_input)]
              return return_val
          except:
              print ("\n INVALID OPTION ! \n")

      return None


def update_search_path(schema_names):
    global db
    query_txt = "SET search_path to '$user', public "

    for ii in range(0,len(schema_names)):
        query_txt = query_txt +  ", " + schema_names[ii][0]

    query_txt = query_txt +";"
    db.execute(query_txt)

# Gets all the schemas
def choose_schema(args):
    global db

    db.execute('''
    SELECT DISTINCT schemaname from pg_catalog.pg_tables;
    ''')

    schema_names = db.fetchall()
    update_search_path(schema_names)
    schema_names = print_sql_col(schema_names)

    #Check if it is a valid input
    if ( len(args)>3 and args[3] in schema_names):
        schema_name=args[3]
    else:
        schema_name = choose_from_list(schema_names, 'schema')

    return schema_name

# Gets all the schemas
def choose_table(args, schema_name):
    global db

    sql_query='''
    SELECT DISTINCT tablename from pg_catalog.pg_tables
    where schemaname = '%s';
    ''' % (schema_name)

    db.execute(sql_query)
    table_names = db.fetchall()
    table_names = print_sql_col(table_names)

    #Check if it is a valid input
    if ( len(args)>4 and args[4] in table_names):
        table_name=args[4]
    else:
        table_name = choose_from_list(table_names, 'table')

    return table_name


def clean_up_col (col):
    res =[]
    for ii in range(0, len(col)):
        res.append(col[ii][0])

    return res

def choose_column(schema_name, table_name):
    global db

    sql_query = '''
    SELECT "column" , "type" from pg_catalog.pg_table_def
    where schemaname = '%s' and tablename = '%s';
    ''' % (schema_name, table_name)
    db.execute(sql_query)
    column_names = db.fetchall()

    print "--------------"
    print "\n "

    print "Keys: \n"
    sql_query =''' SELECT constraint_name from admin.v_constraint_dependency
    where dependent_schemaname = '%s' and dependent_objectname= '%s' ''' % (schema_name, table_name)
    db.execute(sql_query)
    print_sql_col(db.fetchall())

    res=[]
    for ii in range(0, len(column_names)):
        print(column_names[ii][0] + " \t :: \t " + column_names[ii][1])
        res.append(column_names[ii][0])


    key_return =[]
    key_return.append( choose_from_list(res, 'Primary Key'))

    if (key_return[0] == ''):
        return key_return

    db.execute ( '''SELECT COUNT( "%s") From "%s"."%s" where "%s" is null ;''' % (key_return[0], schema_name, table_name, key_return[0]))
    val=db.fetchall()
    print "NULL primary key count: " + str(val[0][0])

    key_return.append( raw_input(' Enter the default : \n'))
    key_return.append( choose_from_list(res, 'DistKey'))
    key_return.append( choose_from_list(res, 'sortKey'))

    return key_return


def create_row_str(row_info, primarykey, default_prime_value):
    row_str = ''' "%s" %s ''' % (row_info[0], row_info[1])

    if (row_info [2] != 'none'):
        row_str  = row_str + " encode " + row_info[2]

    if (row_info [3] == True ):
        row_str  = row_str + " not null"
    elif( primarykey == row_info[0] and default_prime_value != '' ):
        row_str  = row_str + " not null DEFAULT " +  default_prime_value

    row_str = row_str + ", \n"
    return row_str


def update_table_with_keys(schema_name, table_name, primarykey, default_prime_value, distkey, sortkey):

    global master_conn

    sql_query = '''
    SELECT "column", "type" , "encoding", "notnull" from pg_catalog.pg_table_def
    where schemaname = '%s' and tablename = '%s';
    ''' % (schema_name, table_name)
    db.execute(sql_query)
    column_info = db.fetchall()


    #create the query
    add_query='''
    Insert into "%s"."%s_temp" (SELECT
    ''' % (schema_name, table_name)

    recreate_query='''
    Create table "%s"."%s_temp" ( \n''' % (schema_name, table_name)

    for ii in range(0, len(column_info)):
        recreate_query = recreate_query + create_row_str(column_info[ii] , primarykey, default_prime_value)
        add_query = add_query + (''' "%s", ''' % column_info[ii][0])

    recreate_query = recreate_query + ('''
    PRIMARY KEY (%s))
    distkey(%s)
    sortkey(%s);
    ''' % (primarykey, distkey, sortkey))

    print "Recreating the table with the approperiate keyes.... \n"
    print "executing: \n" + recreate_query
    db.execute(recreate_query)
    master_conn.commit()


    # Add the data into the new table
    add_query= add_query[:-2] + ('''
     FROM "%s"."%s" );
    ''' % (schema_name, table_name))

    print "copying all the data to the new table .... \n"
    print "executing: \n" + add_query
    db.execute(add_query)
    master_conn.commit()


    # Rename current table
    change_query='''
    ALTER Table "%s"."%s" rename to "%s_original";
    ''' % (schema_name, table_name, table_name)
    print "renaming old table.... \n"
    print "executing: \n" + change_query
    db.execute(change_query)

    change_query='''
    ALTER Table "%s"."%s_temp" rename to "%s";
    ''' % (schema_name, table_name, table_name)
    print "renaming old table....\n"
    print "executing: \n" + change_query
    db.execute(change_query)

    change_query='''
    ALTER Table "%s"."%s" Owner to fivetran;
    ''' % (schema_name, table_name)
    print "Updating the owner of the table....\n"
    print "executing: \n" + change_query
    db.execute(change_query)

    change_query='''
    Grant SELECT on Table "%s"."%s" to GROUP all_data_viewers;
    Grant ALL on Table "%s"."%s" to GROUP insights_team;
    ''' % (schema_name, table_name, schema_name, table_name)
    print "Updating the access to the new table....\n"
    print "executing: \n" + change_query
    db.execute(change_query)

    master_conn.commit()


    # # Vacuum Table
    print "Vacuum the table"
    old_isolation_level = db_conn.isolation_level
    master_conn.set_isolation_level(0)
    db.execute('''vacuum "%s"."%s";''' % (schema_name, table_name))
    master_conn.set_isolation_level(old_isolation_level)
    db.execute(vacuum_query)


    master_conn.commit()



# main
def main(argv):
    print argv

    global master_conn
    global db

    #Connect to a database
    connect(argv)
    db = master_conn.cursor()

    while (raw_input('Next: (press enter to cancel) \n') != '') :
        # Choose a schema
        schema_name = choose_schema(argv)
        if ( schema_name == ''):
            print "NO ENTRY! ENDING SCRIPT"
            continue
        print "Schemea selected: " + schema_name

        #Choose the table
        table_name=choose_table(argv, schema_name)
        if ( table_name == ''):
            print "NO ENTRY! ENDING SCRIPT"
            continue
        print "Table selected: " + table_name


        # Choose distkey
        key_return = choose_column(schema_name, table_name)
        if (key_return[0] == '' or key_return[2] == '' or key_return[3] == '' ):
            print "NO ENTRY! ENDING SCRIPT"
            continue




        try:
            update_table_with_keys(schema_name, table_name, key_return[0], key_return[1] , key_return[2], key_return[3])
            print "DONE! "
        except ValueError:
            print "Rolling back and closing connection...."
            master_conn.rollback()
            db.close()
            master_conn.close()
            print "Successful close!"


    db.close()
    master_conn.close()


if __name__ == "__main__":
    install_and_import("getpass","getpass")
    install_and_import("psycopg2","psycopg2")
    main(sys.argv)
```






**Helpful Links**

- [Periscope Blog](https://www.periscopedata.com/blog/)
