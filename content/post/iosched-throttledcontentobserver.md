+++
categories = ["Android", "Testing", "iosched"]
date = "2015-05-08T00:47:26+03:00"
description = "Testing com.google.samples.apps.iosched.util.ThrottledContentObserver class from iosched source code"
keywords = []
title = "Google I/O (iosched) - ThrottledContentObserver"

+++

Writing tests for your code is hard.
<br>Even when you start a fresh new project and you can make any choices about the structure of your code, nailing those tests is a challenging task.
<br>In most cases you don't have the privilege of starting a new project. In most cases you are facing existing code (legacy code). Adding tests to existing code is even more challenging.

### Google I/O - iosched
In the next series of posts I will try to demonstrate couple of technics on how to approach this task of adding tests to existing Android codebase.
I started looking for a good candidate, an application complex enough with various features and technologies and then it hit me.

*Google I/O*.

The opened source demo app Google release every year (every I/O conference) to act as a reference to new features and how to build an app in general. This application does not contain tests (WTF Google?! this is how you educated your community?!).

I will try to take this application and make it testable, piece by piece, class by class.

On this post I'll focus on 1 class:

### ThrottledContentObserver

Let's have a look at the class `com.google.samples.apps.iosched.util.ThrottledContentObserver`

```java
/*
 * Copyright 2014 Google Inc. All rights reserved.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

package com.google.samples.apps.iosched.util;

import android.database.ContentObserver;
import android.net.Uri;
import android.os.Handler;

/**
 * A ContentObserver that bundles multiple consecutive changes in a short time period into one.
 * This can be used in place of a regular ContentObserver to protect against getting
 * too many consecutive change events as a result of data changes. This observer will wait
 * a while before firing, so if multiple requests come in in quick succession, they will
 * cause it to fire only once.
 */
public class ThrottledContentObserver extends ContentObserver {
    Handler mMyHandler;
    Runnable mScheduledRun = null;
    private static final int THROTTLE_DELAY = 1000;
    Callbacks mCallback = null;

    public interface Callbacks {
        public void onThrottledContentObserverFired();
    }

    public ThrottledContentObserver(Callbacks callback) {
        super(null);
        mMyHandler = new Handler();
        mCallback = callback;
    }

    @Override
    public void onChange(boolean selfChange) {
        if (mScheduledRun != null) {
            mMyHandler.removeCallbacks(mScheduledRun);
        } else {
            mScheduledRun = new Runnable() {
                @Override
                public void run() {
                    if (mCallback != null) {
                        mCallback.onThrottledContentObserverFired();
                    }
                }
            };
        }
        mMyHandler.postDelayed(mScheduledRun, THROTTLE_DELAY);
    }

    public void cancelPendingCallback() {
        if (mScheduledRun != null) {
            mMyHandler.removeCallbacks(mScheduledRun);
        }
    }

    @Override
    public void onChange(boolean selfChange, Uri uri) {
        onChange(selfChange);
    }
}
```

I consider this class as not easily testable.

Let's make few modifications to this class. The functionality will stay the same, but it will make our life so much easier testing wise.

```java

package com.google.samples.apps.iosched.util;

import android.database.ContentObserver;
import android.net.Uri;
import android.os.Handler;
import android.os.Looper;

/**
 * A ContentObserver that bundles multiple consecutive changes in a short time period into one.
 * This can be used in place of a regular ContentObserver to protect against getting
 * too many consecutive change events as a result of data changes. This observer will wait
 * a while before firing, so if multiple requests come in in quick succession, they will
 * cause it to fire only once.
 */
public class ThrottledContentObserver extends ContentObserver {
    Handler mMyHandler;
    protected static final int THROTTLE_DELAY = 1000;
    Runnable mScheduledRun = null;
    Callbacks mCallback = null;

    public interface Callbacks {
        void onThrottledContentObserverFired();
    }

    public ThrottledContentObserver(Callbacks callback) {
        this(callback, Looper.myLooper());
    }

    public ThrottledContentObserver(Callbacks callback, Looper looper) {
        super(null);
        mMyHandler = createHandler(looper);
        mCallback = callback;
    }

    protected Handler createHandler(Looper looper) {
        return new Handler(looper);
    }

    @Override
    public void onChange(boolean selfChange) {
        if (mScheduledRun != null) {
            mMyHandler.removeCallbacks(mScheduledRun);
        } else {
            mScheduledRun = new Runnable() {
                @Override
                public void run() {
                    if (mCallback != null) {
                        mCallback.onThrottledContentObserverFired();
                    }
                }
            };
        }
        mMyHandler.postDelayed(mScheduledRun, THROTTLE_DELAY);
    }

    public void cancelPendingCallback() {
        if (mScheduledRun != null) {
            mMyHandler.removeCallbacks(mScheduledRun);
        }
    }

    @Override
    public void onChange(boolean selfChange, Uri uri) {
        onChange(selfChange);
    }
}
```

Let's go over the changes:

1. Added new constructor that accepts Looper. This will allow us to "inject" A Looper of our choice during the tests.
2. Refactored the creation of the Handler into a protected method. In the tests we will be able to override this method and provide an alternative Handler implementation that will assist us with the tests.
3. THROTTLE_DELAY changed to protected, so it will be accessible from the test code.

Now it is time for the testing code.
First, let's add a few testing libraries to our project's gradle.

```groovy

...

android {

    ...

    defaultConfig {

        testInstrumentationRunner "android.support.test.runner.AndroidJUnitRunner"
    }

    // Required if using com.android.support.test:testing-support-lib
    packagingOptions {
        exclude 'LICENSE.txt'
        exclude 'LICENSE'
        exclude 'NOTICE'
        exclude 'asm-license.txt'
    }

    ...
}

dependencies {

    ...

    androidTestCompile 'com.android.support.test:runner:0.2'
    // Set this dependency to use JUnit 4 rules
    androidTestCompile 'com.android.support.test:rules:0.2'
    // Set this dependency to build and run Espresso tests
    androidTestCompile 'com.android.support.test.espresso:espresso-core:2.1'

    androidTestCompile 'com.google.dexmaker:dexmaker:1.2'
    androidTestCompile 'com.google.dexmaker:dexmaker-mockito:1.2'
    // The newest version that will work on Android
    androidTestCompile 'org.mockito:mockito-core:1.9.5'

    ...
}

...

```

1. Added testInstrumentationRunner of type `android.support.test.runner.AndroidJUnitRunner`
2. Added `packagingOptions` section
3. Added couple of testing libraries: `android.support.test`, `mockito`

Now, let's see how the test class looks like:

```java
package com.google.samples.apps.iosched.util;

import com.google.samples.apps.iosched.test.MockHandler;

import org.junit.Test;
import org.junit.runner.RunWith;
import org.mockito.Mockito;

import android.net.Uri;
import android.os.Handler;
import android.os.Looper;
import android.support.test.InstrumentationRegistry;
import android.support.test.runner.AndroidJUnit4;

/**
 *
 */
@RunWith(AndroidJUnit4.class)
public class ThrottledContentObserverTest {

    @Test
    public void onChangeShouldTriggerCallbacksAfterDelay() {
        // arrange
        Looper looper = InstrumentationRegistry.getTargetContext().getMainLooper();
        ThrottledContentObserver.Callbacks mockedCallbacks = Mockito.mock(ThrottledContentObserver.Callbacks.class);
        TestableThrottledContentObserver contentObserver =
                new TestableThrottledContentObserver(mockedCallbacks, looper);

        // act
        contentObserver.onChange(true);
        contentObserver.mMockHandler.advanceBy(ThrottledContentObserver.THROTTLE_DELAY);
        InstrumentationRegistry.getInstrumentation().waitForIdleSync();

        // assert
        Mockito.verify(mockedCallbacks).onThrottledContentObserverFired();
    }

    @Test
    public void onChangeShouldNotTriggerCallbacksBeforeDelay() {
        // arrange
        Looper looper = InstrumentationRegistry.getTargetContext().getMainLooper();
        ThrottledContentObserver.Callbacks mockedCallbacks = Mockito.mock(ThrottledContentObserver.Callbacks.class);
        TestableThrottledContentObserver contentObserver =
                new TestableThrottledContentObserver(mockedCallbacks, looper);

        // act
        contentObserver.onChange(true);
        contentObserver.mMockHandler.advanceBy(ThrottledContentObserver.THROTTLE_DELAY - 1);
        InstrumentationRegistry.getInstrumentation().waitForIdleSync();

        // assert
        Mockito.verify(mockedCallbacks, Mockito.never()).onThrottledContentObserverFired();
    }

    @Test
    public void cancelPendingCallbackShouldRemoveFutureCallbackTriggers() {
        // arrange
        Looper looper = InstrumentationRegistry.getTargetContext().getMainLooper();
        ThrottledContentObserver.Callbacks mockedCallbacks = Mockito.mock(ThrottledContentObserver.Callbacks.class);
        TestableThrottledContentObserver contentObserver =
                new TestableThrottledContentObserver(mockedCallbacks, looper);

        // act
        contentObserver.onChange(true, Uri.EMPTY);
        contentObserver.cancelPendingCallback();
        contentObserver.mMockHandler.advanceBy(ThrottledContentObserver.THROTTLE_DELAY);
        InstrumentationRegistry.getInstrumentation().waitForIdleSync();

        // assert
        Mockito.verify(mockedCallbacks, Mockito.never()).onThrottledContentObserverFired();
    }

    private static class TestableThrottledContentObserver extends ThrottledContentObserver {

        private MockHandler mMockHandler;

        public TestableThrottledContentObserver(Callbacks callback, Looper looper) {
            super(callback, looper);
        }

        @Override
        protected Handler createHandler(Looper looper) {
            mMockHandler = new MockHandler(looper);
            return mMockHandler;
        }

    }
}
```

I want to focus on `TestableThrottledContentObserver` class for a minute. This is an inner class in the test file, It's sole purpose is to override `createHandler` method and provide an alternative implementation for Handler.

Let's see what this alternative implementation is:

```java
package com.google.samples.apps.iosched.test;

import android.os.Handler;
import android.os.Looper;
import android.os.Message;
import android.os.SystemClock;
import android.support.annotation.NonNull;

import java.util.LinkedList;
import java.util.Queue;

public class MockHandler extends Handler {

    private final Queue<MessageWrapper> messages;

    public MockHandler(Looper looper) {
        super(looper);
        messages = new LinkedList<>();
    }

    @Override
    public boolean sendMessageAtTime(@NonNull Message msg, long uptimeMillis) {
        messages.add(new MessageWrapper(msg, uptimeMillis));

        // Put this message in the super. This way we can track calls to removeMessages,
        // since we cannot override removeMessages method (it's final).
        // By using Integer.MAX_VALUE as 'when' we make sure super will never dispatch this message
        super.sendMessageAtTime(Message.obtain(msg), Integer.MAX_VALUE);

        return true;
    }

    public void advanceBy(long interval) {
        Queue<MessageWrapper> futureMessages = new LinkedList<>();

        while (!messages.isEmpty()) {
            MessageWrapper messageWrapper = messages.poll();

            if (!super.hasMessages(messageWrapper.message.what)) {
                // do nothing, super does not have this message, it has been removed
                continue;
            }

            long virtualNow = interval + SystemClock.uptimeMillis();

            if (messageWrapper.when <= virtualNow) {

                super.removeMessages(messageWrapper.message.what);
                super.dispatchMessage(messageWrapper.message);

            } else {
                futureMessages.add(new MessageWrapper(
                        messageWrapper.message,
                        messageWrapper.when - virtualNow - 1));
            }
        }

        messages.addAll(futureMessages);
    }

    private static class MessageWrapper {
        private final Message message;
        private final long when;

        private MessageWrapper(Message message, long when) {
            this.message = message;
            this.when = when;
        }
    }
}
```

This `MockHandler` class exposes the method `advanceBy` which allow us to bend time, saving us from annoying `sleep` calls in our testing code.

Going back to our test code, let's look at this test method:

```java
@Test
public void onChangeShouldTriggerCallbacksAfterDelay() {
    // arrange
    Looper looper = InstrumentationRegistry.getTargetContext().getMainLooper();
    ThrottledContentObserver.Callbacks mockedCallbacks = Mockito.mock(ThrottledContentObserver.Callbacks.class);
    TestableThrottledContentObserver contentObserver =
            new TestableThrottledContentObserver(mockedCallbacks, looper);

    // act
    contentObserver.onChange(true);
    contentObserver.mMockHandler.advanceBy(ThrottledContentObserver.THROTTLE_DELAY);
    InstrumentationRegistry.getInstrumentation().waitForIdleSync();

    // assert
    Mockito.verify(mockedCallbacks).onThrottledContentObserverFired();
}
```

We can see the call to `contentObserver.mMockHandler.advanceBy(ThrottledContentObserver.THROTTLE_DELAY)`.
This call will "move forward" in time, and trigger the delayed Runnable.

### Robolectric
I want to take this opportunity and see how these tests would look like when running them using Robolectric library. This can be a way to understand what are few of Roboletric capabilities.

```java
package com.google.samples.apps.iosched.util;

import com.google.samples.apps.iosched.BuildConfig;

import org.junit.Test;
import org.junit.runner.RunWith;
import org.mockito.Mockito;
import org.robolectric.Robolectric;
import org.robolectric.RobolectricGradleTestRunner;
import org.robolectric.RuntimeEnvironment;
import org.robolectric.annotation.Config;

import android.net.Uri;
import android.os.Looper;

/**
 *
 */
@RunWith(RobolectricGradleTestRunner.class)
@Config(constants = BuildConfig.class, emulateSdk = 16)
public class ThrottledContentObserverTest {

    @Test
    public void onChangeShouldTriggerCallbacksAfterDelay() {
        // arrange
        Looper looper = RuntimeEnvironment.application.getMainLooper();
        ThrottledContentObserver.Callbacks mockedCallbacks = Mockito.mock(ThrottledContentObserver.Callbacks.class);
        ThrottledContentObserver contentObserver =
                new ThrottledContentObserver(mockedCallbacks, looper);

        // act
        contentObserver.onChange(true);
        Robolectric.getForegroundThreadScheduler().advanceBy(ThrottledContentObserver.THROTTLE_DELAY);

        // assert
        Mockito.verify(mockedCallbacks).onThrottledContentObserverFired();
    }

    @Test
    public void onChangeShouldNotTriggerCallbacksBeforeDelay() {
        // arrange
        Looper looper = RuntimeEnvironment.application.getMainLooper();
        ThrottledContentObserver.Callbacks mockedCallbacks = Mockito.mock(ThrottledContentObserver.Callbacks.class);
        ThrottledContentObserver contentObserver =
                new ThrottledContentObserver(mockedCallbacks, looper);

        // act
        contentObserver.onChange(true);
        Robolectric.getForegroundThreadScheduler().advanceBy(ThrottledContentObserver.THROTTLE_DELAY - 1);

        // assert
        Mockito.verify(mockedCallbacks, Mockito.never()).onThrottledContentObserverFired();
    }

    @Test
    public void cancelPendingCallbackShouldRemoveFutureCallbackTriggers() {
        // arrange
        Looper looper = RuntimeEnvironment.application.getMainLooper();
        ThrottledContentObserver.Callbacks mockedCallbacks = Mockito.mock(ThrottledContentObserver.Callbacks.class);
        ThrottledContentObserver contentObserver = new ThrottledContentObserver(mockedCallbacks, looper);

        // act
        contentObserver.onChange(true, Uri.EMPTY);
        contentObserver.cancelPendingCallback();
        Robolectric.getForegroundThreadScheduler().advanceBy(ThrottledContentObserver.THROTTLE_DELAY);

        // assert
        Mockito.verify(mockedCallbacks, Mockito.never()).onThrottledContentObserverFired();
    }
}

```
As you can see, we are not required to have `MockHandler` class. Robolectric provide us with the  capability of "moving forward" in time out of the box. Since we are not required to have `MockHandler` we are also not required to have `TestableThrottledContentObserver` either.
