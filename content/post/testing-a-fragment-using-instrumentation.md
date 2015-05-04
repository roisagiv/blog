+++
categories = ["Android", "Testing"]
date = "2014-01-04T12:05:50+02:00"
Tags = ["Android", "Instrumentation"]
title = "Testing a fragment using instrumentation"

+++

Fragments are core component in Android, but somehow the Android SDK does not provide out of the box
way to test them.  
Activities, ContentProviders, Services has their corresponding class (ActivityInstrumentationTestCase2, ProviderTestCase2 and ServiceTestCase), but where is my FragmentTestCase?

One trick I use is an empty Activity class just to contain the Fragment I want to test, and use ActivityInstrumentationTestCase2 to contain my tests.


Let's see an example,  
We want to test a fragment called BooksFragment.  
Let's see how a test class might look like:

{{< highlight java >}}
public class BooksFragmentTest extends ActivityInstrumentationTestCase2<FragmentContainerActivity> {

  private BooksFragment booksFragment;

  public BooksFragmentTest() {
    super(FragmentContainerActivity.class);
  }

  @Override protected void setUp() throws Exception {
    super.setUp();

    booksFragment = new BooksFragment();
    getActivity().addFragment(booksFragment, BooksFragment.class.getSimpleName());
    getInstrumentation().waitForIdleSync();
  }

  public void test_Should_Set_Title_TextView_Text() {
    TextView titleTextView = (TextView) booksFragment.getView().findById(R.id.title);
    assertEqual("some title here", titleTextView.getText().toString());
  }

}
{{< /highlight >}}

And the FragmentContainerActivity class:  
{{< highlight java >}}
public class FragmentContainerActivity extends FragmentActivity {

  private static final int CONTAINER_ID = 1;

  @Override protected void onCreate(Bundle savedInstanceState) {
    super.onCreate(savedInstanceState);

    FrameLayout.LayoutParams params =
        new FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.MATCH_PARENT);
    FrameLayout frameLayout = new FrameLayout(this);
    frameLayout.setId(CONTAINER_ID);

    setContentView(frameLayout, params);
  }

  public void addFragment(Fragment fragment, String tag) {
    getSupportFragmentManager().beginTransaction()
        .add(CONTAINER_ID, fragment, tag)
        .commit();
  }
}
{{< /highlight >}}

One last thing is to add FragmentContainerActivity to the AndroidManifest.xml.  
Since this activity is only for testing purposes a good place to put it is under  
/src/debug/AndroidManifest.xml (if you are using Gradle as the build tool for you app),  
Otherwise add it to the main AndroidManifest.xml and remember to omit it from there before releasing your app.
