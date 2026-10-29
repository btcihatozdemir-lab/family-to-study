# ✈️ FamilyOS - Apple TestFlight & CI/CD Dağıtım Rehberi

Bu rehber, Pardus (Linux) üzerinde geliştirdiğiniz **FamilyOS** kodlarını her `git push` yaptığınızda GitHub Actions bulut sunucuları (macOS) üzerinden otomatik olarak derleyip **Apple TestFlight**'a göndermek için gereken gizli anahtarların (GitHub Secrets) kurulumunu açıklar.

---

## 🔑 GitHub Repository'ye Eklenecek Gizli Anahtarlar (Secrets)

GitHub deponuzda **`Settings` ➔ `Secrets and variables` ➔ `Actions` ➔ `New repository secret`** yolunu izleyerek aşağıdaki 5 anahtarı tanımlayın:

| Secret Adı | Açıklama | Örnek Değer Formatı |
| :--- | :--- | :--- |
| `APPLE_CERTIFICATE_P12_BASE64` | Apple Distribution (Dağıtım) Sertifikası (`.p12` dosyasının base64 metni) | `MIIK... (uzun base64 dizesi)` |
| `APPLE_CERTIFICATE_PASSWORD` | `.p12` sertifikasını dışa aktarırken belirlediğiniz şifre | `Parola123!` |
| `APPLE_PROVISION_PROFILE_BASE64` | App Store Dağıtım Profili (`.mobileprovision` dosyasının base64 metni) | `MIIE... (uzun base64 dizesi)` |
| `APP_STORE_CONNECT_KEY_ID` | App Store Connect API Anahtarı ID'si (10 Karakter) | `D383X7Y464` |
| `APP_STORE_CONNECT_ISSUER_ID` | App Store Connect Issuer ID (UUID Formatında) | `57246542-96fe-1a63-e053-0824d011072a` |
| `APP_STORE_CONNECT_API_KEY_BASE64` | İndirilen `AuthKey_XXXXXX.p8` özel anahtar dosyasının base64 metni | `LS0tLS1CRUdJTi...` |

---

## 🛠️ Adım Adım Anahtarları Hazırlama Kılavuzu

### 1. Apple Dağıtım Sertifikasını (`.p12`) Hazırlama
1. [developer.apple.com](https://developer.apple.com) ➔ **Certificates, Identifiers & Profiles** ➔ **Certificates** bölümüne gidin.
2. **Apple Distribution** sertifikanızı Mac bilgisayarınızın Keychain (Anahtar Zinciri) uygulamasına yükleyin.
3. Keychain üzerinden sertifikanıza sağ tıklayıp **Dışa Aktar (.p12)** seçeneğini seçin ve bir şifre belirleyin (Bu şifre `APPLE_CERTIFICATE_PASSWORD` olacak).
4. Terminalde `.p12` dosyasını tek satır Base64 formatına çevirin:
   ```bash
   base64 -w 0 certificate.p12 > p12_base64.txt
   ```
5. `p12_base64.txt` içeriğini kopyalayıp GitHub Secret `APPLE_CERTIFICATE_P12_BASE64` alanına yapıştırın.

---

### 2. Yetkilendirme Profilini (`.mobileprovision`) Hazırlama
1. [developer.apple.com](https://developer.apple.com) ➔ **Profiles** bölümüne gidin.
2. `com.familytostudy.fam` ve `com.familytostudy.kids` App ID'leriniz için bir **App Store Distribution Profile** oluşturup indirin.
3. Terminalde dosyayı Base64 formatına çevirin:
   ```bash
   base64 -w 0 your_profile.mobileprovision > profile_base64.txt
   ```
4. `profile_base64.txt` içeriğini GitHub Secret `APPLE_PROVISION_PROFILE_BASE64` alanına yapıştırın.

---

### 3. App Store Connect API Anahtarını (`.p8`) Alma
1. [appstoreconnect.apple.com](https://appstoreconnect.apple.com) ➔ **Kullanıcılar ve Erişim (Users and Access)** ➔ **Entegrasyonlar (Integrations / Keys)** sekmesine gidin.
2. **App Store Connect API** başlığı altında yeni bir anahtar oluşturun:
   - **Ad:** `GitHub Actions TestFlight Deployer`
   - **Erişim:** `Admin` veya `App Manager`
3. Sayfadaki **Issuer ID** değerini kopyalayın ➔ `APP_STORE_CONNECT_ISSUER_ID`.
4. Oluşturulan anahtarın **Key ID** değerini kopyalayın ➔ `APP_STORE_CONNECT_KEY_ID`.
5. **API Anahtarını İndir (.p8)** butonuna basarak `AuthKey_XXXXXX.p8` dosyasını bilgisayarınıza indirin (⚠️ Bu dosya yalnızca bir kez indirilebilir!).
6. Terminalde `.p8` dosyasını Base64 formatına çevirin:
   ```bash
   base64 -w 0 AuthKey_XXXXXX.p8 > api_key_base64.txt
   ```
7. `api_key_base64.txt` içeriğini GitHub Secret `APP_STORE_CONNECT_API_KEY_BASE64` alanına yapıştırın.

---

## 🚀 Otomasyonun Çalışma Mantığı

1. Pardus üzerinde geliştirme yapıp terminalden:
   ```bash
   git add .
   git commit -m "feat: yeni özellik eklendi"
   git push origin main
   ```
   komutunu verdiğiniz an GitHub Actions tetiklenir.
2. GitHub'ın bulut macOS sunucusu:
   - Kodları alır ve Flutter SDK'yı hazırlar.
   - Tanımladığınız sertifikalarla uygulamayı resmi olarak imzalar.
   - Apple'ın `xcrun altool` servisini kullanarak paketi doğrudan **TestFlight**'a yükler.
   - Aynı zamanda bağımsız testler için IPA dosyalarını GitHub Releases sayfasına iliştirir.
3. Birkaç dakika içinde sizin, eşinizin ve test grubundaki herkesin iPhone'una:
   > *"FamilyOS yeni bir TestFlight sürümü yayınladı, test etmek için dokunun"*
   bildirimi gelir.
