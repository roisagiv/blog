+++
categories = ["Android", "Testing"]
date = "2014-01-06T20:51:07+02:00"
Tags = ["Android", "Instrumentation"]
title = "Testing a loader using instrumentation"

+++

One of the biggest challenges when authoring instrumentation tests in Android is testing async code.
AsyncTasks, Loaders, Handlers, etc.  
Robolectric for example, provides very convenient tools for this task (take a look at the [Scheduler](https://github.com/robolectric/robolectric/blob/master/src/main/java/org/robolectric/util/Scheduler.java)) class,  
But since we're running instrumentation tests we don't have those tools.

Back to loaders,  
Suppose we have an activity that initiate and load a loader on it's onCreate method.
{{< highlight java >}}
public class BookListActivity extends FragmentActivity
    implements LoaderManager.LoaderCallbacks<List<Book>> {

  protected static final int LOADER_ID_BOOK_LIST = 100;

  // this field will be used in the test to validate onLoadFinished was called
  protected boolean loaderFinished;

  @Override protected void onCreate(Bundle savedInstanceState) {
    super.onCreate(savedInstanceState);

    Loader<List<Book>> loader =
        getSupportLoaderManager().initLoader(LOADER_ID_BOOK_LIST, null, this);
    loader.forceLoad();
  }

  @Override public Loader<List<Book>> onCreateLoader(int i, Bundle bundle) {
    loaderFinished = false;
    return new BooksQueryLoader(this);
  }

  @Override public void onLoadFinished(Loader<List<Book>> loader, List<Book> data) {
    // bind the results to UI elements (ListView, TextView, etc)
    loaderFinished = true;
  }

  @Override public void onLoaderReset(Loader<List<Book>> objectLoader) {

  }
}
{{< /highlight >}}
{{< highlight java >}}
public class BooksQueryLoader extends AsyncTaskLoader<List<Book>> {

  public BooksQueryLoader(Context context) {
    super(context);
  }

  @Override public List<Book> loadInBackground() {
    // do a query here that might take some time

    try {
      // simulate time consuming task
      Thread.sleep(2 * 1000);
    } catch (InterruptedException ignored) {
    }

    return new ArrayList<Book>();
  }
}
{{< /highlight >}}

How would we test the code that executed on onLoadFinished method?  

In one of the times I cruised around the Android source code I stumbled upon the [TestLoaderManager](https://github.com/android/platform_packages_apps_contacts/blob/master/src/com/android/contacts/interactions/TestLoaderManager.java) class.  
Let's see how to use this trick to wait for Loaders to finish (and call onLoadFinished) in a test.

Here is the test:
{{< highlight java >}}
public class BookListActivityTest
    extends ActivityInstrumentationTestCase2<BookListActivity> {

  public BookListActivityTest() {
    super(BookListActivity.class);
  }

  public void testTryingOutTheLoader() {
    BookListActivity activity = getActivity();

    Loader<?> loader =
        activity.getSupportLoaderManager().getLoader(BookListActivity.LOADER_ID_BOOK_LIST);

    // this is where the "magic" happens
    LoaderUtils.waitForLoader(loader);

    // this test passes only if onLoaderFinished method is called
    assertTrue(activity.loaderFinished);
  }
}
{{< /highlight >}}

Here is the code for LoaderUtils (inspired by TestLoaderManager class from the Android source code):
{{< highlight java >}}
public class LoaderUtils {

  public static void waitForLoader(Loader<?> loader) {

    final AsyncTaskLoader<?> asyncTaskLoader
        = (AsyncTaskLoader<?>) loader;

    Thread waitThreads = new Thread("LoaderWaitingThread") {
      @Override
      public void run() {
        try {
          asyncTaskLoader.waitForLoader();
        } catch (Throwable e) {
          Assert.fail("Exception while waiting for loader: "
                + asyncTaskLoader.getId());
        }
      }
    };

    waitThreads.start();

    // Now we wait for all these threads to finish
    try {
      waitThreads.join();
    } catch (InterruptedException ignored) {
    }
  }
}
{{< /highlight >}}
This trick will work with [CursorLoader](http://developer.android.com/reference/android/content/CursorLoader.html) too, as CursorLoader class inherit from AsyncTackLoader class.
