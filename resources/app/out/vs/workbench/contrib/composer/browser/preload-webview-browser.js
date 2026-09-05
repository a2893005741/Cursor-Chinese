
!function(){try{var e="undefined"!=typeof window?window:"undefined"!=typeof global?global:"undefined"!=typeof self?self:{},n=(new e.Error).stack;n&&(e._sentryDebugIds=e._sentryDebugIds||{},e._sentryDebugIds[n]="86e068cf-20bc-56bd-ba8b-2387813866e4")}catch(e){}}();
(function(){"use strict";const{ipcRenderer:a,contextBridge:u,webFrame:s}=require("electron"),d=[".okta.com",".okta-emea.com",".oktapreview.com",".duosecurity.com",".duo.com",".login.microsoftonline.com",".onelogin.com",".auth0.com",".pingidentity.com",".pingone.com",".rippling.com"];function p(){try{const e=window.location.hostname.toLowerCase();if(!d.some(i=>e===i.slice(1)||e.endsWith(i)))return;s.executeJavaScript(`
				(function() {
					if (typeof navigator === 'undefined' || !navigator.permissions || !navigator.permissions.query) {
						return;
					}
					if (navigator.permissions.__localNetworkPolyfillApplied) {
						return;
					}
					navigator.permissions.__localNetworkPolyfillApplied = true;

					const originalQuery = navigator.permissions.query.bind(navigator.permissions);
					navigator.permissions.query = async function(descriptor) {
						if (descriptor && (descriptor.name === 'local-network-access' || descriptor.name === 'local-network')) {
							return {
								state: 'granted',
								name: descriptor.name,
								onchange: null,
								addEventListener: function() {},
								removeEventListener: function() {},
								dispatchEvent: function() { return true; }
							};
						}
						return originalQuery(descriptor);
					};
				})();
			`)}catch(e){console.error("[WebviewBrowser Preload] Failed to inject local network access polyfill:",e)}}function f(){try{s.executeJavaScript(`
				(function() {
					if (typeof navigator === 'undefined' || !navigator.credentials) {
						return;
					}
					if (navigator.credentials.__webAuthnPolyfillApplied) {
						return;
					}
					navigator.credentials.__webAuthnPolyfillApplied = true;

					var WEBAUTHN_NOTIFY_DELAY_MS = 10000;
					var WEBAUTHN_MIN_TIMEOUT_MS = 30000;
					var WEBAUTHN_DEFAULT_TIMEOUT_MS = 300000;
					var WEBAUTHN_MAX_TIMEOUT_MS = 600000;
					var lastNotifiedPasskeyAt = -Infinity;
					function notify(channel) {
						var now = Date.now();
						if (now - lastNotifiedPasskeyAt < WEBAUTHN_NOTIFY_DELAY_MS) {
							return;
						}
						lastNotifiedPasskeyAt = now;
						try {
							if (window.cursorBrowser && window.cursorBrowser.send) {
								window.cursorBrowser.send(channel);
							}
						} catch (error) {
							console.debug('[WebviewBrowser Preload] Failed to notify passkey support status:', error);
						}
					}

					function createNotSupportedError() {
						return new DOMException(
							'WebAuthn is not supported in the Cursor browser.',
							'NotSupportedError'
						);
					}

					function createAbortError() {
						return new DOMException('The operation was aborted.', 'AbortError');
					}

					function createTimeoutError() {
						return new DOMException(
							'The WebAuthn request timed out in the Cursor browser.',
							'NotAllowedError'
						);
					}

					function createConditionalMediationError() {
						return new DOMException(
							'Conditional mediation is not supported in the Cursor browser.',
							'NotSupportedError'
						);
					}

					function createHybridOnlyError() {
						return new DOMException(
							'This passkey is on another device (phone or tablet) and requires a QR code, which the Cursor browser cannot display.',
							'NotAllowedError'
						);
					}

					// Get-only by design: a get() whose allowCredentials all list
					// only hybrid can never complete without QR UI, so fail it
					// fast. create() has no allowCredentials and phone-via-QR
					// registration is a legitimate flow, so it is not gated here.
					function isHybridOnlyRequest(options) {
						var allowCredentials = options && options.publicKey && options.publicKey.allowCredentials;
						if (!Array.isArray(allowCredentials) || allowCredentials.length === 0) {
							return false;
						}
						return allowCredentials.every(function(credential) {
							return credential
								&& Array.isArray(credential.transports)
								&& credential.transports.length > 0
								&& credential.transports.every(function(transport) {
									return transport === 'hybrid' || transport === 'cable';
								});
						});
					}

					function getEffectiveTimeoutMs(options) {
						var requestedTimeout = options && options.publicKey && options.publicKey.timeout;
						var requested = typeof requestedTimeout === 'number' && Number.isFinite(requestedTimeout)
							? requestedTimeout
							: WEBAUTHN_DEFAULT_TIMEOUT_MS;
						return Math.min(Math.max(requested, WEBAUTHN_MIN_TIMEOUT_MS), WEBAUTHN_MAX_TIMEOUT_MS);
					}

					var origCreate = navigator.credentials.create;
					var origGet = navigator.credentials.get;

					function wrapWebAuthnRequest(originalMethod, options, args) {
						if (!originalMethod) {
							return Promise.reject(createNotSupportedError());
						}
						if (options.mediation === 'conditional') {
							return Promise.reject(createConditionalMediationError());
						}
						if (isHybridOnlyRequest(options)) {
							notify('passkey-hybrid-unsupported');
							return Promise.reject(createHybridOnlyError());
						}

						var callerSignal = options && options.signal;
						if (callerSignal && callerSignal.aborted) {
							return Promise.reject(callerSignal.reason || createAbortError());
						}

						var abortController = typeof AbortController === 'function'
							? new AbortController()
							: undefined;
						var abortListener;
						var requestArgs = Array.prototype.slice.call(args);
						if (abortController) {
							requestArgs[0] = Object.assign({}, options, { signal: abortController.signal });
						}

						var notifyTimeout;
						var abortTimeout;
						var didFinish = false;
						var didNotify = false;
						function notifyIfNeeded() {
							if (didNotify) {
								return;
							}
							didNotify = true;
							notify('passkey-request-stalled');
						}
						function cleanup() {
							clearTimeout(notifyTimeout);
							clearTimeout(abortTimeout);
							if (callerSignal && abortListener) {
								callerSignal.removeEventListener('abort', abortListener);
							}
						}

						return new Promise(function(resolve, reject) {
							function resolveIfActive(value) {
								if (didFinish) {
									return;
								}
								didFinish = true;
								cleanup();
								resolve(value);
							}

							function rejectIfActive(error) {
								if (didFinish) {
									return;
								}
								didFinish = true;
								cleanup();
								reject(error);
							}

							if (callerSignal && callerSignal.addEventListener) {
								abortListener = function() {
									if (abortController) {
										abortController.abort();
									}
									rejectIfActive(callerSignal.reason || createAbortError());
								};
								callerSignal.addEventListener('abort', abortListener, { once: true });
							}

							notifyTimeout = setTimeout(function() {
								if (!didFinish) {
									notifyIfNeeded();
								}
							}, WEBAUTHN_NOTIFY_DELAY_MS);

							abortTimeout = setTimeout(function() {
								if (didFinish) {
									return;
								}
								notifyIfNeeded();
								if (abortController) {
									abortController.abort();
								}
								rejectIfActive(createTimeoutError());
							}, getEffectiveTimeoutMs(options));

							Promise.resolve().then(function() {
								return originalMethod.apply(navigator.credentials, requestArgs);
							}).then(
								resolveIfActive,
								rejectIfActive
							);
						});
					}

					navigator.credentials.create = function(options) {
						if (options && options.publicKey) {
							return wrapWebAuthnRequest(origCreate, options, arguments);
						}
						return origCreate ? origCreate.apply(navigator.credentials, arguments) : Promise.reject(createNotSupportedError());
					};

					navigator.credentials.get = function(options) {
						if (options && options.publicKey) {
							return wrapWebAuthnRequest(origGet, options, arguments);
						}
						return origGet ? origGet.apply(navigator.credentials, arguments) : Promise.reject(createNotSupportedError());
					};

					if (typeof PublicKeyCredential !== 'undefined') {
						if (typeof PublicKeyCredential.isConditionalMediationAvailable === 'function') {
							PublicKeyCredential.isConditionalMediationAvailable = function() {
								return Promise.resolve(false);
							};
						}
						if (typeof PublicKeyCredential.getClientCapabilities === 'function') {
							var origGetClientCapabilities = PublicKeyCredential.getClientCapabilities.bind(PublicKeyCredential);
							PublicKeyCredential.getClientCapabilities = function() {
								return origGetClientCapabilities.apply(undefined, arguments).then(function(capabilities) {
									var patched = Object.assign({}, capabilities);
									patched.conditionalGet = false;
									patched.conditionalCreate = false;
									return patched;
								});
							};
						}
					}
				})();
			`)}catch(e){console.error("[WebviewBrowser Preload] Failed to inject WebAuthn polyfill:",e)}}p(),f();const l=process.platform==="darwin",g={send:(e,...t)=>{["focus-url-bar","element-selected","element-updated","element-picked","element-hovered","selection-resynced","selection-restored","area-screenshot-selected","open-url-side-group","open-url-new-tab","focus-composer-input","show-dialog","show-dialog-dummy","passkey-request-stalled","passkey-hybrid-unsupported","browser-error-action"].includes(e)&&a.sendToHost(e,...t)}};try{u.exposeInMainWorld("cursorBrowser",g)}catch(e){console.error("[WebviewBrowser Preload] Failed to expose bridge:",e)}function c(){const e=`
			(function() {
				if (window.__cursorDialogOverridesApplied) {
					return;
				}
				window.__cursorDialogOverridesApplied = true;

				window.__cursorDialogConfig = {
					confirmResult: true,
					promptResult: null,
					dialogHistory: []
				};

				window.__cursorSetDialogConfig = function(config) {
					if (typeof config.confirmResult === 'boolean') {
						window.__cursorDialogConfig.confirmResult = config.confirmResult;
					}
					if (config.promptResult !== undefined) {
						window.__cursorDialogConfig.promptResult = config.promptResult;
					}
				};

				window.__cursorGetDialogHistory = function() {
					return window.__cursorDialogConfig.dialogHistory.slice();
				};

				window.__cursorClearDialogHistory = function() {
					window.__cursorDialogConfig.dialogHistory = [];
				};

				window.alert = function(message) {
					const msgStr = String(message ?? '');
					console.log('[CursorBrowser] Dialog suppressed: alert - ' + msgStr);
					window.__cursorDialogConfig.dialogHistory.push({ type: 'alert', message: msgStr, timestamp: Date.now() });
					return undefined;
				};

				window.confirm = function(message) {
					const msgStr = String(message ?? '');
					const result = window.__cursorDialogConfig.confirmResult;
					console.log('[CursorBrowser] Dialog suppressed: confirm - ' + msgStr + ' (returning ' + result + ')');
					window.__cursorDialogConfig.dialogHistory.push({ type: 'confirm', message: msgStr, result: result, timestamp: Date.now() });
					return result;
				};

				window.prompt = function(message, defaultValue) {
					const msgStr = String(message ?? '');
					const defVal = defaultValue ?? '';
					const configuredResult = window.__cursorDialogConfig.promptResult;
					const result = configuredResult !== null ? configuredResult : defVal;
					console.log('[CursorBrowser] Dialog suppressed: prompt - ' + msgStr + ' (returning: ' + result + ')');
					window.__cursorDialogConfig.dialogHistory.push({ type: 'prompt', message: msgStr, defaultValue: defVal, result: result, timestamp: Date.now() });
					return result;
				};

				console.log('[CursorBrowser] Native dialog overrides installed - dialogs are now non-blocking');
			})();
		`;try{s.executeJavaScript(e)}catch(t){console.error("[WebviewBrowser Preload] Failed to inject early dialog overrides:",t)}}c(),window.addEventListener("DOMContentLoaded",()=>{c(),document.addEventListener("click",e=>{if(!e.altKey)return;const t=e.target.closest("a[href]");if(!t)return;const o=t.href;!o||o.startsWith("javascript:")||(e.preventDefault(),e.stopPropagation(),a.sendToHost("open-url-side-group",{url:o}))},!0)}),document.addEventListener("keydown",e=>{if(!e.isTrusted)return;const t=l?e.metaKey:e.ctrlKey,o=e.shiftKey,i=e.altKey,n=e.key.toLowerCase();let r;if(t&&!o&&!i)switch(n){case"r":r="reload-page";break;case"l":r="focus-url-bar";break;case"t":r="new-browser-tab";break;case"i":r="focus-composer";break;case"f":r="find-in-page";break;case"b":r="toggle-sidebar";break;case"w":r="close-browser-tab";break;case"=":case"+":r="zoom-in";break;case"-":r="zoom-out";break;case"0":r="zoom-reset";break;case"z":r="undo";break;case"a":r="select-all";break;case"c":r="copy";break;case"v":r="paste";break;case"x":r="cut";break;case"[":r="navigate-back";break;case"]":r="navigate-forward";break;case"d":r="toggle-bookmark";break}if(t&&o&&!i)switch(n){case"i":r="open-devtools";break;case"z":r="redo";break}if(i&&!t&&!o)switch(n){case"arrowleft":r="navigate-back";break;case"arrowright":r="navigate-forward";break}if(!t&&!o&&!i)switch(n){case"f5":r="reload-page";break;case"f12":r="open-devtools";break}if(l&&e.metaKey&&e.altKey&&!o)switch(n){case"i":case"c":case"j":r="open-devtools";break}r&&(e.preventDefault(),a.sendToHost("keyboard-shortcut",{shortcut:r})),a.sendToHost("did-keydown",{key:e.key,keyCode:e.keyCode,code:e.code,shiftKey:e.shiftKey,altKey:e.altKey,ctrlKey:e.ctrlKey,metaKey:e.metaKey,repeat:e.repeat,browserShortcut:r})},!0)})();

//# sourceMappingURL=http://go/sourcemap/sourcemaps/90de2327392570a5f5f625c656c6749d228e6430/core/vs/workbench/contrib/composer/browser/preload-webview-browser.js.map

//# debugId=86e068cf-20bc-56bd-ba8b-2387813866e4
