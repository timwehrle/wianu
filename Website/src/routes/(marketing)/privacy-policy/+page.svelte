<script lang="ts">
	import Button from '#lib/components/Button.svelte';
	import LegalPage from '#lib/components/LegalPage.svelte';
	import { openPrivacySettings } from '#lib/privacy/analytics.js';
</script>

<svelte:head>
	<title>Privacy Policy - Wianu</title>
	<meta
		name="description"
		content="How the Wianu website processes personal data, and how to exercise your privacy rights."
	/>
</svelte:head>

<LegalPage title="Privacy policy">
	<p class="updated">Last updated: 15 October 2026</p>
	<section>
		<h2>Scope and controller</h2>
		<p>
			This policy covers the Wianu website and its API. The controller
			responsible for processing personal data is:
		</p>
		<address>
			<ul>
				<li>Tim Wehrle</li>
				<li>Senefelderstraße 37A</li>
				<li>70176 Stuttgart</li>
				<li>Germany</li>
				<li><a href="mailto:hello@wianu.com">hello@wianu.com</a></li>
			</ul>
		</address>
		<p>
			This website notice also applies when the Wianu app contacts our API. It
			does not cover the app's local storage, embedded browser, update service,
			or native usage analytics. The website's analytics choice does not change
			the app's analytics setting. Streaming services accessed through the app
			provide their own privacy notices.
		</p>
	</section>
	<section>
		<h2>Hosting and technical data</h2>
		<p>
			The website is self-managed on infrastructure provided by Hetzner in
			Nuremberg, Germany. Hosting involves processing connection data, including
			your IP address, to deliver the website.
		</p>
		<p>
			The application records the time, request identifier, HTTP method, route,
			response status, and processing duration for requests. The hosting
			infrastructure may also process IP addresses, requested URLs, browser
			information, and technical errors in access or error logs.
		</p>
		<p>
			We process this information to operate the website, diagnose errors, and
			protect it against abuse. The legal basis is Article 6(1)(f) GDPR, based
			on our legitimate interest in a secure, reliable service. Technical
			records are retained only for as long as needed for these purposes,
			including investigating security incidents, or to meet legal obligations.
		</p>
		<p>
			For API abuse prevention, IP addresses are held temporarily in application
			memory. Inactive entries become eligible for removal after ten minutes and
			are cleared during subsequent API traffic. Admin login attempts are also
			limited using temporary IP-based records.
		</p>
		<p>
			Our API receives movie and TV search terms, requested media identifiers,
			language and region preferences when you use discovery features. It sends
			these parameters to TMDB from our server to retrieve results. It does not
			forward your IP address, cookies, or browser headers with these requests.
			Search responses are cached for up to two minutes and media details for up
			to 30 minutes; expired cache entries are no longer served and are removed
			when accessed or evicted. This processing provides the discovery feature
			you request, under Article 6(1)(b) GDPR.
		</p>
		<p>
			Further information: <a
				href="https://www.hetzner.com/legal/privacy-policy/"
				target="_blank"
				rel="noopener noreferrer">Hetzner's privacy policy</a
			>.
		</p>
	</section>
	<section>
		<h2>Cookies and privacy preferences</h2>
		<p>
			The website does not use advertising trackers or marketing cookies. Fonts
			are hosted on our own server.
		</p>
		<p>
			We store your analytics choice in a necessary first-party cookie named
			<code>wianu_analytics_consent</code> for 180 days. Its value records only whether
			you allowed or rejected website analytics and the preference version. It is
			not a visitor identifier. You can change the choice at any time using “Privacy
			settings” in the footer. Storing the choice is based on § 25(2)(2) TDDDG; processing
			it is based on our legitimate interest in respecting your privacy preferences
			under Article 6(1)(f) GDPR.
		</p>
	</section>
	<section id="analytics-settings">
		<h2>Umami analytics</h2>
		<p>
			Only if you allow it, we use Umami to understand how visitors use this
			website and improve its content. The analytics service is self-hosted by
			us at
			<code>analytics.timwehrle.de</code> on Hetzner infrastructure in Germany. Analytics
			requests go to our own service rather than Umami Cloud.
		</p>
		<p>
			Umami records page views, page titles, referring websites, browser
			language, screen size, browser and operating system, device type, and
			approximate location derived from connection information. Your IP address
			is processed to receive requests and derive these statistics; Umami does
			not store the raw IP address in its analytics database. Infrastructure
			logs may still contain connection data as described above. Umami uses no
			tracking cookies, and we do not provide it with account identifiers. We
			exclude URL query parameters and fragments from tracked page and referrer
			URLs. Administration pages are excluded.
		</p>
		<p>
			The legal basis is your consent under Article 6(1)(a) GDPR and § 25(1)
			TDDDG. The tracker is not loaded before you allow analytics. Rejecting
			analytics does not restrict access to the website. By default, self-hosted
			Umami retains analytics records until they are manually deleted.
		</p>
		<p>
			You can withdraw consent at any time using “Privacy settings” in the
			footer or the button below. Withdrawal stops further collection and does
			not affect the lawfulness of processing before withdrawal. We also respect
			your browser's Do Not Track setting. Further information about the
			software is available in the
			<a
				href="https://docs.umami.is/docs/faq"
				target="_blank"
				rel="noopener noreferrer">Umami documentation</a
			>.
		</p>
		<Button
			class="privacy-action"
			type="button"
			onclick={openPrivacySettings}>Change analytics choice</Button
		>
		<noscript
			><p>
				Website analytics is disabled when JavaScript is disabled.
			</p></noscript
		>
	</section>
	<section>
		<h2>Film images and metadata</h2>
		<p>
			Film images and metadata are provided by The Movie Database (TMDB). Images
			on this website are delivered through our server. Your browser requests
			them from this website, and our server fetches them from TMDB without
			forwarding your IP address, cookies, or browser headers. Cached images may
			be reused for up to 24 hours.
		</p>
		<p>
			Film metadata is requested by our server from TMDB; your browser does not
			contact the TMDB API for these requests. We use this service to display
			film recommendations, based on our legitimate interest under Article
			6(1)(f) GDPR. These server requests send our server's connection
			information and the requested film data or image path to TMDB.
		</p>
		<p>
			Further information: <a
				href="https://www.themoviedb.org/privacy-policy"
				target="_blank"
				rel="noopener noreferrer">TMDB's privacy policy</a
			>.
		</p>
	</section>
	<section>
		<h2>Downloads and external links</h2>
		<p>
			App downloads redirect to GitHub. Following a download or another external
			link sends connection data to the destination provider, which processes it
			under its own privacy policy. See <a
				href="https://docs.github.com/en/site-policy/privacy-policies/github-general-privacy-statement"
				target="_blank"
				rel="noopener noreferrer">GitHub's privacy statement</a
			> for downloads.
		</p>
	</section>
	<section>
		<h2>Contact by email</h2>
		<p>
			If you email us, we process your email address, message, and any
			information you provide to respond to your enquiry. Depending on its
			subject, the legal basis is Article 6(1)(b) GDPR for contractual or
			pre-contractual enquiries, or Article 6(1)(f) GDPR for our legitimate
			interest in answering other messages. Correspondence is kept for as long
			as needed to handle the enquiry and any applicable legal retention
			obligations.
		</p>
	</section>
	<section>
		<h2>Your rights</h2>
		<p>
			Subject to the applicable legal conditions, you may request access,
			correction, erasure, restriction of processing, and data portability. You
			may object to processing based on legitimate interests on grounds relating
			to your particular situation. Where processing relies on consent, you may
			withdraw it at any time without affecting earlier lawful processing.
		</p>
		<p>
			Contact <a href="mailto:hello@wianu.com">hello@wianu.com</a> to exercise
			your rights. You may also complain to a data protection supervisory
			authority, including the
			<a
				href="https://www.baden-wuerttemberg.datenschutz.de/"
				target="_blank"
				rel="noopener noreferrer"
				>State Commissioner for Data Protection and Freedom of Information
				Baden-Württemberg</a
			>.
		</p>
		<p>
			You do not have to provide personal information to browse, beyond the
			technical data necessary to deliver the website. We do not use your data
			for automated decision-making or profiling.
		</p>
	</section>
</LegalPage>

<style>
	.updated {
		margin-bottom: var(--space-8);
		color: var(--secondary-foreground);
		font-size: var(--text-small);
	}
	#analytics-settings {
		scroll-margin-top: var(--page-top);
	}
	#analytics-settings :global(.privacy-action) {
		margin-top: var(--space-5);
	}
</style>
