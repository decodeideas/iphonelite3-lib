/*
 Copyright (c) 2009 copyright@de-co-de.com
 
 Permission is hereby granted, free of charge, to any person
 obtaining a copy of this software and associated documentation
 files (the "Software"), to deal in the Software without
 restriction, including without limitation the rights to use,
 copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the
 Software is furnished to do so, subject to the following
 conditions:
 
 The above copyright notice and this permission notice shall be
 included in all copies or substantial portions of the Software.
 
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
 OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
 HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
 WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
 OTHER DEALINGS IN THE SOFTWARE.
 */
#import "GTMSenTestCase.h"
#import "GTMUnitTestDevLog.h"
#import "Lite3DB.h"
#import "Lite3Table.h"
#import "Lite3LinkTable.h"

#import "User.h"
#import "Group.h"

@interface GroupTest : SenTestCase {
    Lite3DB * db;
    Lite3Table * groupsTable;
    Lite3Table * usersTable;
}

@end

static const char * ddl = 
"create table \"users\" ("
"\"id\" INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,"
"\"name\" varchar(255)"
");"
"create table \"groups\" ("
"\"id\" INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,"
"\"name\" varchar(255) "
");"
"create table \"groups_users\" ("
"  group_id integer,"
"  user_id integer"
");"
;



@implementation GroupTest

/**
 * Test helper: build input data to be used for the import of users.
 * In normal operation the input may be generated by a web service so it won't come through as objects but as a dictionary.
 */
-(NSArray*) buildImportUsers {
    id user1 = [NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects: @"1", @"user1",nil] forKeys:[NSArray arrayWithObjects: @"id", @"name", nil]];
    id user2 = [NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects: @"2", @"user2",nil] forKeys:[NSArray arrayWithObjects: @"id", @"name", nil]];
    id user3 = [NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects: @"3", @"user3",nil] forKeys:[NSArray arrayWithObjects: @"id", @"name", nil]];
    NSArray * users = [NSArray arrayWithObjects: user1, user2, user3, nil];
    STAssertNotNil ( users, @"users is nil", users );
    STAssertGreaterThan( (int)[users count], 0, @"users is empty", nil );
    return users;
}

/**
 * Test helper: build input data to be used for the import of groups.
 */
-(NSArray*) buildImportGroups {
    id group1 = [NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects: @"1", @"group1", [NSArray arrayWithObjects: @"1", @"2", @"3",nil],nil] forKeys:[NSArray arrayWithObjects: @"id", @"name", @"user_ids", nil]];
    id group2 = [NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects: @"2", @"group1", [NSArray arrayWithObjects: @"1", @"2", @"3",nil],nil] forKeys:[NSArray arrayWithObjects: @"id", @"name", @"user_ids", nil]];
    NSArray * groups = [NSArray arrayWithObjects: group1, group2, nil];
    STAssertNotNil ( groups, @"groups is nil", groups );
    STAssertGreaterThan( (int)[groups count], 0, @"groups is empty", nil );
    return groups;
}


- (void)setUp {
    db = [[Lite3DB alloc] initWithDbName: @"user_test" andSql:[NSString stringWithCString:ddl]];
    usersTable = [[Lite3Table lite3TableName: @"users" withDb: db forClassName:@"User"] retain];
    groupsTable = [[Lite3Table lite3TableName: @"groups" withDb: db forClassName:@"Group"] retain];
    // need to traverse all the tables and fix the references 
    [db checkConsistency];
    
}

- (void) testDDL {
    // we expect two tables to be created
    NSArray * tables  =[db listTables];
    STAssertNotNil( tables, @"No tables", nil );
    STAssertEquals( (int)[tables count], 3, @"Wrong number of tables, got %d", [tables count]);
}

- (void)testGroupsTableSetup {
    STAssertNotNil( groupsTable, @"Valid groupsTable", nil );
    STAssertTrue( [groupsTable tableExists], @"Table regions does not exist", nil );
    STAssertTrue( [groupsTable isValid], @"Table regions is not valid", nil );
    STAssertNotNil( [groupsTable linkTableFor: @"users"], nil, @"No linked table for users", nil );
}

-(void)testUsersTableSetup {
    STAssertNotNil( usersTable, @"Valid usersTable", nil );
    STAssertTrue( [usersTable tableExists], @"Table places does not exist", nil );    
    STAssertTrue( [usersTable isValid], @"Table places is not valid", nil );    
    STAssertNotNil( usersTable.arguments, @"Bad arguments in usersTable", nil );
}

- (void)testGroupsLinkedTableSetup {
    Lite3LinkTable * groupsUsers = [groupsTable linkTableFor: @"users"];
    STAssertNotNil( groupsUsers, @"Empty linkedTables", nil );
    STAssertNotNil( groupsUsers.ownTable, @"LinkedTable does not have its own table", nil );
    STAssertTrue( [groupsUsers.ownTable tableExists], @"LinkedTable not in the database %@", groupsUsers.ownTable.tableName );
}


- (void)testImportSimple {
    NSArray * users = [self buildImportUsers];
    [usersTable truncate];
    STAssertEquals( 0, [usersTable count], @"Users table not empty after truncate, instead %d", [usersTable count] );
    
    // IMPORT
    [usersTable updateAll: users]; 
    
    STAssertEquals ( (int)[users count], (int)[usersTable count], @"Users table does not have proper count of rows %d", [usersTable count] ); 
    
    [usersTable truncate];
    STAssertEquals( 0, [usersTable count], @"Users table not empty after truncate, instead %d", [usersTable count] );
    
}

- (void) testImportManyToMany {    
    NSArray * groups = [self buildImportGroups];
    Lite3LinkTable * groupsUsers = [groupsTable linkTableFor: @"users"];
    
    [groupsTable truncate];
    STAssertEquals( 0, [groupsTable count], @"Groups table not empty after truncate, instead %d", [groupsTable count] );
    STAssertEquals( (int)[groupsUsers.ownTable count], 0, @"Linked table is not empty %d",  [groupsUsers.ownTable count] );

    // IMPORT
    [groupsTable updateAll: groups];
    
    // TEST SOME MORE    
    STAssertEquals ( (int)[groups count], (int)[groupsTable count], @"Groups table does not have proper count of rows %d", [groupsTable count] );
    
    int linksCount = [groupsUsers.ownTable count];
    STAssertGreaterThan( linksCount, 0, @"Linked table is empty", nil);
    STAssertEquals( linksCount, 6, @"Bad number of links %d", linksCount );
    NSArray * linksForGroup1 = [groupsUsers.ownTable select: @"group_id = 1"];
    STAssertNotNil( linksForGroup1, @"No links for group id 1", nil );
    STAssertEquals ( (int)[linksForGroup1 count], 3, @"%d bad count for links of group 1", (int)[linksForGroup1 count] );

    // truncate one more time
    [groupsTable truncate];
    STAssertEquals( 0, [groupsTable count], @"Groups table not empty after truncate, instead %d", [groupsTable count] );
    STAssertEquals( (int)[groupsUsers.ownTable count], 0, @"Linked table is not empty %d",  [groupsUsers.ownTable count] );
    
     
}

- (void)testAccessSimple {
    NSArray * users  = [self buildImportUsers];
    [usersTable updateAll: users];
    User * user = (User*)[usersTable selectFirst: @"id = 1"];
    STAssertNotNil( user, @"Cannot fetch user", nil );
    STAssertEquals( user._id, 1, @"Fetched wrong user %@", user );
    user = (User*)[usersTable selectFirst: @"id = 100"];
    STAssertNil( user, @"User should have been nil not %@", user);
}

- (void) testAccessManyToMany {    
    [usersTable truncate];
    [groupsTable truncate];
    [usersTable updateAll: [self buildImportUsers]];
    NSArray * users = [usersTable select: nil];
    STAssertNotNil( users, @"No users", nil );
    STAssertEquals ( (int)[users count], 3, @"%d is wrong user count", (int)[users count]);
    NSArray * groups = [self buildImportGroups];
    [groupsTable updateAll: groups];
    Group * group = (Group*)[groupsTable selectFirst: @"id = 100"];
    STAssertNil( group, @"Group should have been nil not %@", group);
    group = (Group*)[groupsTable selectFirst: @"id = 1"];
    STAssertNotNil( group, @"Cannot fetch group", nil );
    STAssertEquals( group._id, 1 , @"Fetched wrong group %@", group );
    NSArray * usersForGroup = [groupsTable filterArray: users forOwner: group andProperty: @"users"];
    STAssertNotNil( usersForGroup, @"Group has null users", nil );
    STAssertEquals ( (int)[usersForGroup count], 3, @"%d is the wrong number of users", (int)[usersForGroup count] );
    User * firstUser = [usersForGroup objectAtIndex:0];
    STAssertNotNil( firstUser, @"First user is empty", nil );
    STAssertGreaterThan( firstUser._id, 0, @"First user has no id", nil );
    
}

- (void)tearDown {
    [usersTable release];
    [groupsTable release];
    [db release];
    
}

@end
