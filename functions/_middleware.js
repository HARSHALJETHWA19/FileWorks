export async function onRequest(context) {
  const url = new URL(context.request.url);
  if (url.pathname === '/google66569072dd92a036.html' || url.pathname === '/google66569072dd92a036') {
    return new Response('google-site-verification: google66569072dd92a036.html', {
      status: 200,
      headers: {
        'content-type': 'text/html; charset=utf-8',
        'cache-control': 'public, max-age=0, must-revalidate',
      },
    });
  }
  return context.next();
}
