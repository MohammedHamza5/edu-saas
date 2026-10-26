const fs = require('fs');
const path = require('path');

const target = (process.argv[2] || 'test').toLowerCase();
const buildDir = path.join(__dirname, '..', 'build', 'web');
const indexPath = path.join(buildDir, 'index.html');
const manifestPath = path.join(buildDir, 'manifest.json');

console.log(`[Target Metadata] Preparing build/web assets for target: "${target}"...`);

if (!fs.existsSync(indexPath)) {
  console.error(`Error: ${indexPath} not found! Compile build/web first.`);
  process.exit(1);
}

if (target === 'test') {
  // 1. Process index.html for Demo / Test Sandbox
  let html = fs.readFileSync(indexPath, 'utf8');

  // Replace Title & SEO Meta Tags
  html = html.replace(
    /<title>.*?<\/title>/s,
    '<title>منصة رياضيات الدبلومة الأمريكية (نسخة تجريبية) | American Math Platform (Demo)</title>'
  );
  html = html.replace(
    /<meta name="title" content=".*?">/s,
    '<meta name="title" content="منصة رياضيات الدبلومة الأمريكية (نسخة تجريبية) | American Math Platform">'
  );
  html = html.replace(
    /<meta name="description" content=".*?">/s,
    '<meta name="description" content="معاينة حية للمنصة التعليمية الذكية لطلاب الدبلومة الأمريكية (SAT • ACT • EST). اكتشف تجربة الطالب المتطورة ولوحة تحكم المعلم.">'
  );
  html = html.replace(
    /<meta name="keywords" content=".*?">/s,
    '<meta name="keywords" content="منصة رياضيات, الدبلومة الامريكية, SAT, ACT, EST, Bluebook, Desmos, edsentre, demo.edsentre.com">'
  );
  html = html.replace(
    /<meta name="author" content=".*?">/s,
    '<meta name="author" content="American Math Platform (Demo)">'
  );
  html = html.replace(
    /<link rel="canonical" href=".*?">/s,
    '<link rel="canonical" href="https://demo.edsentre.com/">'
  );

  // Replace Open Graph (Facebook / WhatsApp / Messenger / Telegram Preview)
  html = html.replace(
    /<meta property="og:url" content=".*?">/s,
    '<meta property="og:url" content="https://demo.edsentre.com/">'
  );
  html = html.replace(
    /<meta property="og:site_name" content=".*?">/s,
    '<meta property="og:site_name" content="منصة رياضيات الدبلومة الأمريكية (نسخة تجريبية)">'
  );
  html = html.replace(
    /<meta property="og:title" content=".*?">/s,
    '<meta property="og:title" content="منصة رياضيات الدبلومة الأمريكية (نسخة تجريبية) | American Math Platform">'
  );
  html = html.replace(
    /<meta property="og:description" content=".*?">/s,
    '<meta property="og:description" content="معاينة حية للمنصة التعليمية الذكية لطلاب الدبلومة الأمريكية (SAT • ACT • EST). استكشف تجربة الطالب ولوحة المعلم.">'
  );

  // Replace Twitter Card Preview
  html = html.replace(
    /<meta name="twitter:url" content=".*?">/s,
    '<meta name="twitter:url" content="https://demo.edsentre.com/">'
  );
  html = html.replace(
    /<meta name="twitter:title" content=".*?">/s,
    '<meta name="twitter:title" content="منصة رياضيات الدبلومة الأمريكية (نسخة تجريبية)">'
  );
  html = html.replace(
    /<meta name="twitter:description" content=".*?">/s,
    '<meta name="twitter:description" content="معاينة حية للمنصة التعليمية لطلاب الدبلومة الأمريكية (SAT • ACT • EST)">'
  );

  // Replace Schema.org JSON-LD
  const demoJsonLd = `<script type="application/ld+json">
  {
    "@context": "https://schema.org",
    "@graph": [
      {
        "@type": "WebSite",
        "@id": "https://demo.edsentre.com/#website",
        "url": "https://demo.edsentre.com/",
        "name": "منصة رياضيات الدبلومة الأمريكية (نسخة تجريبية)",
        "description": "معاينة حية للمنصة التعليمية لطلاب الدبلومة الأمريكية SAT, EST, ACT",
        "inLanguage": ["ar", "en"]
      },
      {
        "@type": "EducationalOrganization",
        "@id": "https://demo.edsentre.com/#organization",
        "name": "منصة رياضيات الدبلومة الأمريكية",
        "url": "https://demo.edsentre.com/"
      }
    ]
  }
  </script>`;
  html = html.replace(/<script type="application\/ld\+json">.*?<\/script>/s, demoJsonLd);

  // Replace Preloader Titles
  html = html.replace(
    /<h1 class="preloader-title" id="preloader-main-title">.*?<\/h1>/s,
    '<h1 class="preloader-title" id="preloader-main-title">منصة رياضيات الدبلومة الأمريكية</h1>'
  );
  html = html.replace(
    /<p class="preloader-subtitle" id="preloader-main-subtitle">.*?<\/p>/s,
    '<p class="preloader-subtitle" id="preloader-main-subtitle">Digital SAT • ACT • EST &bull; معاينة تجريبية</p>'
  );

  // Replace Crawler Content
  const demoCrawlerContent = `<div id="seo-crawler-content" style="position: absolute; left: -9999px; width: 1px; height: 1px; overflow: hidden;" aria-hidden="false">
    <header>
      <h1>منصة رياضيات الدبلومة الأمريكية (نسخة تجريبية) | American Math Platform</h1>
      <h2>المنصة التعليمية لطلاب الدبلومة الأمريكية - American High School (SAT / EST / ACT)</h2>
    </header>
    <main>
      <article>
        <p>مرحباً بكم في منصة رياضيات الدبلومة الأمريكية (نسخة تجريبية). المنصة التعليمية المتخصصة في تأهيل طلاب الدبلومة الأمريكية لاجتياز امتحانات SAT و EST و ACT بأعلى الدرجات ومحاكاة نظام Bluebook.</p>
        <p>Live demo for American High School Math SaaS platform (Digital SAT, ACT, EST).</p>
      </article>
    </main>
  </div>`;
  html = html.replace(/<div id="seo-crawler-content".*?<\/div>/s, demoCrawlerContent);

  // Replace noscript
  const demoNoscript = `<noscript>
    <div style="padding: 24px; font-family: sans-serif; text-align: center; direction: rtl; color: #ffffff; background-color: #0F172A;">
      <h1>منصة رياضيات الدبلومة الأمريكية (نسخة تجريبية)</h1>
      <p>المنصة التعليمية لطلاب الدبلومة الأمريكية SAT, EST, ACT.</p>
      <p>American High School Curriculum - Better Scores, Bigger Dreams.</p>
    </div>
  </noscript>`;
  html = html.replace(/<noscript>.*?<\/noscript>/s, demoNoscript);

  // Remove any remaining mentions of Dr. Antounios
  html = html.split('دكتور أنطونيوس أشرف').join('معلم تجريبي (معاينة المنصة)');
  html = html.split('د. أنطونيوس أشرف').join('معلم تجريبي (معاينة المنصة)');
  html = html.split('Dr. Antounios Ashraf').join('Demo Teacher (Platform Preview)');
  html = html.split('Dr Antounios').join('Demo Platform');
  html = html.split('antounios.edsentre.com').join('demo.edsentre.com');

  // Write updated index.html with UTF-8 encoding
  fs.writeFileSync(indexPath, html, 'utf8');
  console.log('✓ index.html successfully scrubbed and configured with Demo OpenGraph & SEO tags');

  // 2. Process manifest.json for Demo
  if (fs.existsSync(manifestPath)) {
    try {
      const manifest = JSON.parse(fs.readFileSync(manifestPath, 'utf8'));
      manifest.name = 'منصة رياضيات الدبلومة الأمريكية (نسخة تجريبية)';
      manifest.short_name = 'معاينة المنصة';
      manifest.description =
        'معاينة حية للمنصة التعليمية لطلاب الدبلومة الأمريكية (Digital SAT • ACT • EST)';
      fs.writeFileSync(manifestPath, JSON.stringify(manifest, null, 2), 'utf8');
      console.log('✓ manifest.json configured for Demo');
    } catch (e) {
      console.warn('Warning: could not update manifest.json:', e.message);
    }
  }
} else {
  console.log('✓ Production target detected: Preserving canonical Dr. Antounios Ashraf SEO tags.');
}

console.log('[Target Metadata] Complete.');
