const HELPIN_PIXEL = (widgetKey) => `
<script type="text/javascript">
  (function () {
    window.helpin = window.helpin || function () {
      (window.helpinQ = window.helpinQ || []).push(arguments);
    };
    var t = document.createElement('script'),
        s = document.getElementsByTagName('script')[0];
    t.defer = true;
    t.id = 'helpin-widget';
    t.setAttribute('data-widget-key', ${JSON.stringify(widgetKey)});
    t.setAttribute('data-host', 'https://client.helpin.ai');
    t.setAttribute('data-support-only', 'true');
    t.src = 'https://cdn.helpin.ai/lib.js';
    s.parentNode.insertBefore(t, s);
  })();
</script>`;

export default {
  async fetch(request, env) {
    const response = await env.ASSETS.fetch(request);
    const contentType = response.headers.get('content-type') || '';

    if (!env.HELPIN_WIDGET_KEY || !contentType.includes('text/html')) {
      return response;
    }

    return new HTMLRewriter()
      .on('body', {
        element(element) {
          element.append(HELPIN_PIXEL(env.HELPIN_WIDGET_KEY), { html: true });
        },
      })
      .transform(response);
  },
};
