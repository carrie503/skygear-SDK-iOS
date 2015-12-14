//
//  SKYFetchSubscriptionsOperationTests.m
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

#import <UIKit/UIKit.h>
#import <SKYKit/SKYKit.h>
#import <OHHTTPStubs/OHHTTPStubs.h>

SpecBegin(SKYFetchSubscriptionsOperation)

    describe(@"fetch subscription", ^{
        __block SKYContainer *container = nil;
        __block SKYDatabase *database = nil;

        beforeEach(^{
            container = [[SKYContainer alloc] init];
            [container configureWithAPIKey:@"API_KEY"];
            [container updateWithUserRecordID:[SKYUserRecordID recordIDWithUsername:@"USER_ID"]
                                  accessToken:[[SKYAccessToken alloc]
                                                  initWithTokenString:@"ACCESS_TOKEN"]];
            database = [container publicCloudDatabase];
        });

        it(@"single subscription", ^{
            SKYFetchSubscriptionsOperation *operation =
                [SKYFetchSubscriptionsOperation operationWithSubscriptionIDs:@[ @"sub1" ]];
            operation.deviceID = @"DEVICE_ID";
            operation.container = container;
            operation.database = database;

            [operation prepareForRequest];

            SKYRequest *request = operation.request;
            expect([request class]).to.beSubclassOf([SKYRequest class]);
            expect(request.APIKey).to.equal(@"API_KEY");
            expect(request.accessToken).to.equal(container.currentAccessToken);
            expect(request.action).to.equal(@"subscription:fetch");
            expect(request.payload)
                .to.equal(@{
                    @"database_id" : database.databaseID,
                    @"ids" : @[ @"sub1" ],
                    @"device_id" : @"DEVICE_ID",
                });

        });

        it(@"multiple subscriptions", ^{
            SKYFetchSubscriptionsOperation *operation =
                [SKYFetchSubscriptionsOperation operationWithSubscriptionIDs:@[ @"sub1", @"sub2" ]];
            operation.deviceID = @"DEVICE_ID";
            operation.container = container;
            operation.database = database;

            [operation prepareForRequest];

            SKYRequest *request = operation.request;
            expect([request class]).to.beSubclassOf([SKYRequest class]);
            expect(request.APIKey).to.equal(@"API_KEY");
            expect(request.accessToken).to.equal(container.currentAccessToken);
            expect(request.action).to.equal(@"subscription:fetch");
            expect(request.payload)
                .to.equal(@{
                    @"database_id" : database.databaseID,
                    @"ids" : @[ @"sub1", @"sub2" ],
                    @"device_id" : @"DEVICE_ID",
                });
        });

        it(@"make request", ^{
            SKYFetchSubscriptionsOperation *operation =
                [SKYFetchSubscriptionsOperation operationWithSubscriptionIDs:@[ @"sub1", @"sub2" ]];
            operation.container = container;
            operation.database = database;

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
                               @"type" : @"query",
                               @"query" : @{
                                   @"record_type" : @"book",
                               }
                            },
                            @{
                               @"id" : @"sub2",
                               @"type" : @"query",
                               @"query" : @{
                                   @"record_type" : @"bookmark",
                               }
                            },
                        ]
                    };
                    NSData *payload =
                        [NSJSONSerialization dataWithJSONObject:parameters options:0 error:nil];

                    return
                        [OHHTTPStubsResponse responseWithData:payload statusCode:200 headers:@{}];
                }];

            waitUntil(^(DoneCallback done) {
                operation.fetchSubscriptionCompletionBlock =
                    ^(NSDictionary *subscriptionByID, NSError *operationError) {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            expect([subscriptionByID class]).to.beSubclassOf([NSDictionary class]);
                            expect(subscriptionByID).to.haveCountOf(2);

                            SKYSubscription *sub1 = subscriptionByID[@"sub1"];
                            expect(sub1.subscriptionID).to.equal(@"sub1");
                            expect(sub1.query.recordType).to.equal(@"book");

                            SKYSubscription *sub2 = subscriptionByID[@"sub2"];
                            expect(sub2.subscriptionID).to.equal(@"sub2");
                            expect(sub2.query.recordType).to.equal(@"bookmark");

                            done();
                        });
                    };

                [database executeOperation:operation];
            });
        });

        it(@"pass error", ^{
            SKYFetchSubscriptionsOperation *operation =
                [SKYFetchSubscriptionsOperation operationWithSubscriptionIDs:@[ @"sub1", @"sub2" ]];
            operation.container = container;
            operation.database = database;
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
                operation.fetchSubscriptionCompletionBlock =
                    ^(NSDictionary *recordsByRecordID, NSError *operationError) {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            expect(operationError).toNot.beNil();
                            done();
                        });
                    };
                [database executeOperation:operation];
            });
        });

        describe(@"when there exists device id", ^{
            __block SKYFetchSubscriptionsOperation *operation;

            beforeEach(^{
                id odDefaultsMock = OCMClassMock(SKYDefaults.class);
                OCMStub([odDefaultsMock sharedDefaults]).andReturn(odDefaultsMock);
                OCMStub([odDefaultsMock deviceID]).andReturn(@"EXISTING_DEVICE_ID");

                operation = [[SKYFetchSubscriptionsOperation alloc] initWithSubscriptionIDs:@[]];
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
