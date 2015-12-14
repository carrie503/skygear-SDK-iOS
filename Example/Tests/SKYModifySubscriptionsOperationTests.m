//
//  SKYModifySubscriptionsOperationTests.m
//  SKYKit
//
//  Copyright 2015 Oursky Ltd.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

#import <Foundation/Foundation.h>
#import <SKYKit/SKYKit.h>
#import <OHHTTPStubs/OHHTTPStubs.h>

SpecBegin(SKYModifySubscriptionsOperation)

    describe(@"modify subscription", ^{
        __block SKYSubscription *subscription1 = nil;
        __block SKYSubscription *subscription2 = nil;
        __block SKYContainer *container = nil;
        __block SKYDatabase *database = nil;

        beforeEach(^{
            container = [[SKYContainer alloc] init];
            [container configureWithAPIKey:@"API_KEY"];
            [container updateWithUserRecordID:[SKYUserRecordID recordIDWithUsername:@"USER_ID"]
                                  accessToken:[[SKYAccessToken alloc]
                                                  initWithTokenString:@"ACCESS_TOKEN"]];
            database = [container publicCloudDatabase];
            subscription1 = [[SKYSubscription alloc] initWithQuery:nil subscriptionID:@"sub1"];
            subscription2 = [[SKYSubscription alloc] initWithQuery:nil subscriptionID:@"sub2"];
        });

        it(@"multiple subscriptions", ^{
            SKYModifySubscriptionsOperation *operation = [SKYModifySubscriptionsOperation
                operationWithSubscriptionsToSave:@[ subscription1, subscription2 ]];
            operation.deviceID = @"DEVICE_ID";
            operation.container = container;
            operation.database = database;
            [operation prepareForRequest];
            SKYRequest *request = operation.request;
            expect([request class]).to.beSubclassOf([SKYRequest class]);
            expect(request.action).to.equal(@"subscription:save");
            expect(request.APIKey).to.equal(@"API_KEY");
            expect(request.accessToken).to.equal(container.currentAccessToken);
            expect(request.payload)
                .to.equal(@{
                    @"database_id" : database.databaseID,
                    @"subscriptions" : @[
                        @{@"id" : @"sub1", @"type" : @"query"},
                        @{@"id" : @"sub2", @"type" : @"query"},
                    ],
                    @"device_id" : @"DEVICE_ID",
                });
        });

        it(@"make request", ^{
            SKYModifySubscriptionsOperation *operation = [SKYModifySubscriptionsOperation
                operationWithSubscriptionsToSave:@[ subscription1, subscription2 ]];

            [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
                return YES;
            }
                withStubResponse:^OHHTTPStubsResponse *(NSURLRequest *request) {
                    NSDictionary *parameters = @{
                        @"request_id" : @"REQUEST_ID",
                        @"database_id" : database.databaseID,
                        @"result" : @[
                            @{
                               @"id" : @"sub1",
                               @"type" : @"subscription",
                            },
                            @{
                               @"id" : @"sub2",
                               @"type" : @"subscription",
                            }
                        ]
                    };
                    NSData *payload =
                        [NSJSONSerialization dataWithJSONObject:parameters options:0 error:nil];

                    return
                        [OHHTTPStubsResponse responseWithData:payload statusCode:200 headers:@{}];
                }];

            waitUntil(^(DoneCallback done) {
                operation.modifySubscriptionsCompletionBlock =
                    ^(NSArray *savedSubscriptions, NSError *operationError) {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            expect([savedSubscriptions class]).to.beSubclassOf([NSArray class]);
                            expect(savedSubscriptions).to.haveCountOf(2);
                            expect([savedSubscriptions[0] subscriptionID])
                                .to.equal(subscription1.subscriptionID);
                            expect([savedSubscriptions[1] subscriptionID])
                                .to.equal(subscription2.subscriptionID);
                            done();
                        });
                    };

                [database executeOperation:operation];
            });
        });

        it(@"pass error", ^{
            SKYModifySubscriptionsOperation *operation = [SKYModifySubscriptionsOperation
                operationWithSubscriptionsToSave:@[ subscription1, subscription2 ]];
            [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
                return YES;
            }
                withStubResponse:^OHHTTPStubsResponse *(NSURLRequest *request) {
                    return [OHHTTPStubsResponse
                        responseWithError:[NSError errorWithDomain:NSURLErrorDomain
                                                              code:0
                                                          userInfo:nil]];
                }];

            waitUntil(^(DoneCallback done) {
                operation.modifySubscriptionsCompletionBlock =
                    ^(NSArray *savedSubscriptions, NSError *operationError) {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            expect(operationError).toNot.beNil();
                            done();
                        });
                    };
                [database executeOperation:operation];
            });
        });

        describe(@"when there exists device id", ^{
            __block SKYModifySubscriptionsOperation *operation;

            beforeEach(^{
                id odDefaultsMock = OCMClassMock(SKYDefaults.class);
                OCMStub([odDefaultsMock sharedDefaults]).andReturn(odDefaultsMock);
                OCMStub([odDefaultsMock deviceID]).andReturn(@"EXISTING_DEVICE_ID");

                operation = [SKYModifySubscriptionsOperation operationWithSubscriptionsToSave:@[]];
                operation.container = container;
                operation.database = database;
            });

            it(@"request with device id", ^{
                [operation prepareForRequest];
                expect(operation.request.payload[@"device_id"]).to.equal(@"EXISTING_DEVICE_ID");
            });

            it(@"user-set device id overrides existing device id", ^{
                operation.deviceID = @"ASSIGNED_DEVICE_ID";
                [operation prepareForRequest];
                expect(operation.request.payload[@"device_id"]).to.equal(@"ASSIGNED_DEVICE_ID");
            });
        });

        afterEach(^{
            [OHHTTPStubs removeAllStubs];
        });
    });

SpecEnd
