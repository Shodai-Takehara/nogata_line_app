// LIFF initialization
document.addEventListener('DOMContentLoaded', () => {
  // 開発モードかどうかをチェック
  const devMode = document.querySelector('meta[name="dev-mode"]') !== null;

  if (devMode) {
    console.log('Running in development mode with mocked LIFF API');

    // モックLIFF APIを定義
    window.liff = {
      init: (options) => Promise.resolve(),
      isLoggedIn: () => false,
      login: () => {
        console.log('LIFF login called');
        // 開発モードでログインボタンをクリックしたら、ユーザー情報をモックで表示
        setTimeout(() => {
          const mockProfile = {
            userId: 'dev-user-id',
            displayName: '開発ユーザー',
            pictureUrl: 'https://via.placeholder.com/150',
            statusMessage: '開発モード中'
          };

          if (typeof window.displayUserInfo === 'function') {
            window.displayUserInfo(mockProfile);
          }
        }, 500);
      },
      getProfile: () => Promise.resolve({
        userId: 'dev-user-id',
        displayName: '開発ユーザー',
        pictureUrl: 'https://via.placeholder.com/150',
        statusMessage: '開発モード中'
      })
    };

    // ログインボタンにイベントリスナーを追加
    setupLoginButton();

    return; // 開発モードの処理はここまで
  }

  // 以下は本番モードの処理

  const liffIdMeta = document.querySelector('meta[name="liff-id"]');
  const liffId = liffIdMeta ? liffIdMeta.content : null;

  console.log('LIFF ID from meta tag:', liffId);

  if (!liffId || liffId === 'null' || liffId === '') {
    console.error('LIFF ID is missing. Please set it in the meta tag.');
    return;
  }

  try {
    // LIFFが定義されていなければエラー
    if (typeof liff === 'undefined') {
      console.error('LIFF SDK is not loaded.');
      return;
    }

    // 通常通り初期化
    liff.init({
      liffId: liffId
    }).then(() => {
      console.log('LIFF initialized successfully');

      // Check if user is logged in
      if (!liff.isLoggedIn()) {
        // Setup login button
        setupLoginButton();
      } else {
        console.log('User is logged in');
        // Get user profile
        liff.getProfile()
          .then(profile => {
            console.log('User profile:', profile);
            // ユーザープロフィール情報を表示する関数を呼び出す
            if (typeof window.displayUserInfo === 'function') {
              window.displayUserInfo(profile);
            }
          })
          .catch(err => {
            console.error('Error getting user profile:', err);
          });
      }
    }).catch(err => {
      console.error('LIFF initialization failed:', err);
    });
  } catch (error) {
    console.error('Error in LIFF initialization:', error);
  }
});

// ログインボタンの設定関数
function setupLoginButton() {
  const loginButton = document.getElementById('loginButton');
  if (loginButton) {
    loginButton.addEventListener('click', () => {
      if (window.liff) {
        window.liff.login();
      }
    });
  }
}
