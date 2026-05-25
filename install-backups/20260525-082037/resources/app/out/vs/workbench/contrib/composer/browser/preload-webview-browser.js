
!function(){try{var e="undefined"!=typeof window?window:"undefined"!=typeof global?global:"undefined"!=typeof self?self:{},n=(new e.Error).stack;n&&(e._sentryDebugIds=e._sentryDebugIds||{},e._sentryDebugIds[n]="76139498-f2bd-5c63-b0db-360a730ffd32")}catch(e){}}();
(function(){"use strict";const{ipcRenderer:s,contextBridge:u,webFrame:a}=require("electron"),d=[".okta.com",".okta-emea.com",".oktapreview.com",".duosecurity.com",".duo.com",".login.microsoftonline.com",".onelogin.com",".auth0.com",".pingidentity.com",".pingone.com",".rippling.com"];function f(){try{const e=window.location.hostname.toLowerCase();if(!d.some(i=>e===i.slice(1)||e.endsWith(i)))return;a.executeJavaScript(`
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
			`)}catch(e){console.error("[WebviewBrowser Preload] 本地网络访问 polyfill 注入失败:",e)}}function g(){try{a.executeJavaScript(`
				(function() {
					if (typeof navigator === 'undefined' || !navigator.credentials) {
						return;
					}
					if (navigator.credentials.__webAuthnPolyfillApplied) {
						return;
					}
					navigator.credentials.__webAuthnPolyfillApplied = true;

					var WEBAUTHN_NOTIFY_DELAY_MS = 10000;
					var WEBAUTHN_ABORT_DELAY_MS = 45000;
					var lastNotifiedPasskeyAt = 0;
					function notify() {
						var now = Date.now();
						if (now - lastNotifiedPasskeyAt < WEBAUTHN_NOTIFY_DELAY_MS) {
							return;
						}
						lastNotifiedPasskeyAt = now;
						try {
							if (window.cursorBrowser && window.cursorBrowser.send) {
								window.cursorBrowser.send('passkey-request-stalled');
							}
						} catch (error) {
							console.debug('[WebviewBrowser Preload] 通知 passkey 支持状态失败:', error);
						}
					}

					function createNotSupportedError() {
						return new DOMException(
							'Cursor 浏览器不支持 WebAuthn。',
							'NotSupportedError'
						);
					}

					function createAbortError() {
						return new DOMException('操作已中止。', 'AbortError');
					}

					function createTimeoutError() {
						return new DOMException(
							'Cursor 浏览器中的 WebAuthn 请求已超时。',
							'TimeoutError'
						);
					}

					function wrapWebAuthnRequest(originalMethod, options, args) {
						if (!originalMethod) {
							return Promise.reject(createNotSupportedError());
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
							notify();
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
							}, WEBAUTHN_ABORT_DELAY_MS);

							Promise.resolve().then(function() {
								return originalMethod.apply(navigator.credentials, requestArgs);
							}).then(
								resolveIfActive,
								rejectIfActive
							);
						});
					}

					var origCreate = navigator.credentials.create;
					var origGet = navigator.credentials.get;

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
						PublicKeyCredential.isUserVerifyingPlatformAuthenticatorAvailable = function() {
							return Promise.resolve(false);
						};
						if (typeof PublicKeyCredential.isConditionalMediationAvailable === 'function') {
							PublicKeyCredential.isConditionalMediationAvailable = function() {
								return Promise.resolve(false);
							};
						}
					}
				})();
			`)}catch(e){console.error("[WebviewBrowser Preload] WebAuthn polyfill 注入失败:",e)}}f(),g();const l=process.platform==="darwin",p={send:(e,...o)=>{["focus-url-bar","element-selected","element-updated","element-picked","element-hovered","area-screenshot-selected","style-changes-confirmed","css-inspector-style-change","open-url-side-group","open-url-new-tab","focus-composer-input","css-inspector-undo","css-inspector-redo","show-dialog","show-dialog-dummy","passkey-request-stalled","browser-error-action"].includes(e)&&s.sendToHost(e,...o)}};try{u.exposeInMainWorld("cursorBrowser",p)}catch(e){console.error("[WebviewBrowser Preload] 桥接暴露失败:",e)}function c(){const e=`
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
					console.log('[CursorBrowser] 已屏蔽对话框：alert - ' + msgStr);
					window.__cursorDialogConfig.dialogHistory.push({ type: 'alert', message: msgStr, timestamp: Date.now() });
					return undefined;
				};

				window.confirm = function(message) {
					const msgStr = String(message ?? '');
					const result = window.__cursorDialogConfig.confirmResult;
					console.log('[CursorBrowser] 已屏蔽对话框：confirm - ' + msgStr + '（返回 ' + result + ')');
					window.__cursorDialogConfig.dialogHistory.push({ type: 'confirm', message: msgStr, result: result, timestamp: Date.now() });
					return result;
				};

				window.prompt = function(message, defaultValue) {
					const msgStr = String(message ?? '');
					const defVal = defaultValue ?? '';
					const configuredResult = window.__cursorDialogConfig.promptResult;
					const result = configuredResult !== null ? configuredResult : defVal;
					console.log('[CursorBrowser] 已屏蔽对话框：prompt - ' + msgStr + '（返回：' + result + ')');
					window.__cursorDialogConfig.dialogHistory.push({ type: 'prompt', message: msgStr, defaultValue: defVal, result: result, timestamp: Date.now() });
					return result;
				};

				console.log('[CursorBrowser] 已安装原生对话框覆盖，弹窗现在不会阻塞。');
			})();
		`;try{a.executeJavaScript(e)}catch(o){console.error("[WebviewBrowser Preload] 早期对话框覆盖注入失败:",o)}}function __cursorApplyComposerUiTextOverrides(){const e=`
			(function() {
				if (window.__cursorComposerUiTextOverridesApplied) {
					return;
				}
				window.__cursorComposerUiTextOverridesApplied = true;

				const textMap = new Map([
					['Review', '查看改动']
				]);

				function applyTextOverrides(root) {
					const scope = root && root.nodeType === Node.ELEMENT_NODE ? root : document.body;
					if (!scope) {
						return;
					}

					const walker = document.createTreeWalker(scope, NodeFilter.SHOW_TEXT);
					let node;
					while ((node = walker.nextNode())) {
						const raw = node.nodeValue || '';
						const trimmed = raw.trim();
						const translated = textMap.get(trimmed);
						if (translated) {
							node.nodeValue = raw.replace(trimmed, translated);
						}
					}

					const elements = scope.querySelectorAll ? scope.querySelectorAll('[aria-label], [title], [placeholder], input[value], button') : [];
					for (const element of elements) {
						for (const attr of ['aria-label', 'title', 'placeholder', 'value']) {
							const value = element.getAttribute && element.getAttribute(attr);
							const translated = textMap.get((value || '').trim());
							if (translated) {
								element.setAttribute(attr, translated);
							}
						}
						const ownText = element.childNodes.length === 1 && element.firstChild.nodeType === Node.TEXT_NODE ? element.textContent.trim() : '';
						const translated = textMap.get(ownText);
						if (translated) {
							element.textContent = translated;
						}
					}
				}

				applyTextOverrides(document.body);
				const observer = new MutationObserver((mutations) => {
					for (const mutation of mutations) {
						for (const node of mutation.addedNodes) {
							applyTextOverrides(node);
						}
						if (mutation.type === 'characterData') {
							applyTextOverrides(mutation.target.parentElement);
						}
					}
				});
				observer.observe(document.documentElement, { childList: true, subtree: true, characterData: true });
			})();
		`;try{a.executeJavaScript(e)}catch(o){console.error("[WebviewBrowser Preload] Composer 文案覆盖注入失败:",o)}}c(),__cursorApplyComposerUiTextOverrides(),window.addEventListener("DOMContentLoaded",()=>{c(),__cursorApplyComposerUiTextOverrides(),document.addEventListener("click",e=>{if(!e.altKey)return;const o=e.target.closest("a[href]");if(!o)return;const t=o.href;!t||t.startsWith("javascript:")||(e.preventDefault(),e.stopPropagation(),s.sendToHost("open-url-side-group",{url:t}))},!0)}),document.addEventListener("keydown",e=>{if(!e.isTrusted)return;const o=l?e.metaKey:e.ctrlKey,t=e.shiftKey,i=e.altKey,n=e.key.toLowerCase();let r;if(o&&!t&&!i)switch(n){case"r":r="reload-page";break;case"l":r="focus-url-bar";break;case"t":r="new-browser-tab";break;case"i":r="focus-composer";break;case"b":r="toggle-sidebar";break;case"w":r="close-browser-tab";break;case"=":case"+":r="zoom-in";break;case"-":r="zoom-out";break;case"0":r="zoom-reset";break;case"z":r="undo";break;case"a":r="select-all";break;case"c":r="copy";break;case"v":r="paste";break;case"x":r="cut";break;case"[":r="navigate-back";break;case"]":r="navigate-forward";break;case"d":r="toggle-bookmark";break}if(o&&t&&!i)switch(n){case"i":r="open-devtools";break;case"z":r="redo";break}if(i&&!o&&!t)switch(n){case"arrowleft":r="navigate-back";break;case"arrowright":r="navigate-forward";break}if(!o&&!t&&!i)switch(n){case"f5":r="reload-page";break;case"f12":r="open-devtools";break}if(l&&e.metaKey&&e.altKey&&!t)switch(n){case"i":case"c":case"j":r="open-devtools";break}r&&(e.preventDefault(),s.sendToHost("keyboard-shortcut",{shortcut:r})),s.sendToHost("did-keydown",{key:e.key,keyCode:e.keyCode,code:e.code,shiftKey:e.shiftKey,altKey:e.altKey,ctrlKey:e.ctrlKey,metaKey:e.metaKey,repeat:e.repeat})},!0)})();

//# sourceMappingURL=http://go/sourcemap/sourcemaps/d5b2fc092e16007956c9e5047f76097b9e626ca0/core/vs/workbench/contrib/composer/browser/preload-webview-browser.js.map

//# debugId=76139498-f2bd-5c63-b0db-360a730ffd32
