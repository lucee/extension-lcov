// Global dark mode toggle function
function toggleDarkMode() {
	const currentMode = localStorage.getItem('darkMode') || 'auto';
	const toggle = document.getElementById('darkModeToggle') || document.querySelector('.dark-mode-toggle');
	let newMode;
	
	if (currentMode === 'auto') {
		// From auto, go to opposite of system preference
		if (window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches) {
			newMode = 'light';
		} else {
			newMode = 'dark';
		}
	} else if (currentMode === 'dark') {
		newMode = 'light';
	} else {
		newMode = 'dark';
	}
	
	updateMode(newMode, toggle);
}

function updateMode(mode, toggle) {
	if (mode === 'dark') {
		document.body.classList.add('dark-mode');
		if (toggle) toggle.innerHTML = '☀️ Light';
	} else if (mode === 'light') {
		document.body.classList.remove('dark-mode');
		if (toggle) toggle.innerHTML = '🌙 Dark';
	} else { // auto
		document.body.classList.remove('dark-mode');
		if (toggle) {
			if (window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches) {
				toggle.innerHTML = '☀️ Light';
			} else {
				toggle.innerHTML = '🌙 Dark';
			}
		}
	}
	localStorage.setItem('darkMode', mode);
}

function initDarkModeToggle() {
	// Check for saved dark mode preference or default to 'auto'
	const savedMode = localStorage.getItem('darkMode') || 'auto';
	const toggle = document.getElementById('darkModeToggle') || document.querySelector('.dark-mode-toggle');
	
	// Initialize based on saved preference
	updateMode(savedMode, toggle);
	
	// Listen for system preference changes when in auto mode
	if (window.matchMedia) {
		window.matchMedia('(prefers-color-scheme: dark)').addListener(function() {
			const currentMode = localStorage.getItem('darkMode') || 'auto';
			if (currentMode === 'auto') {
				const toggle = document.getElementById('darkModeToggle') || document.querySelector('.dark-mode-toggle');
				updateMode('auto', toggle);
			}
		});
	}
}

// Initialize when DOM is loaded
if (document.readyState === 'loading') {
	document.addEventListener('DOMContentLoaded', initDarkModeToggle);
} else {
	initDarkModeToggle();
}