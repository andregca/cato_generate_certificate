# Certificate Generation Script

This project provides a Bash 3.2-compatible script that automates the process of generating a Root Certificate Authority (CA) and device certificates using OpenSSL and a YAML configuration file.

## Features

- Creates a Root CA with a password-protected key
- Creates a device private key and certificate signed by the Root CA
- Converts certificates to PEM and PKCS#12 formats
- Stores all certificates in a dedicated `certs/` directory
- Configurable via a single YAML file (`cert_config.yml`)

## Requirements

- Bash 3.2+
- `openssl`
- [`yq`](https://github.com/mikefarah/yq) (YAML processor)

## Usage

### 1. Clone the repository

```bash
git clone <repo-url>
cd <repo-directory>
```

### 2. Create configuration

Before running the script, create a configuration file named `cert_config.yml` based on the provided `cert_config-sample.yml`.

### 3. Run the script

```bash
./generate-certificates.sh
```

If `cert_config.yml` is not found, the script will exit with an error. If any required parameter is missing from the configuration file, the script will list the missing keys and exit.

### 4. Review generated files

All generated certificate files will be placed in the `certs/` directory.

## Files Created

| File               | Description                                     |
| ------------------ | ----------------------------------------------- |
| `rootCA.key`       | Root CA private key (password protected)        |
| `rootCA.crt`       | Root CA certificate                             |
| `rootCA.pem`       | Root CA certificate in PEM format (for CMA)     |
| `device.key`       | Device private key                              |
| `device.csr`       | Certificate Signing Request for the device      |
| `device.crt`       | Signed device certificate                       |
| `device.p12`       | PKCS#12 bundle for SDP clients                  |
| `device_macos.p12` | PKCS#12 bundle for SDP clients                  |

## Configuration

Edit `cert_config.yml` to customize subject fields, filenames, and certificate lifetimes. All paths are relative to the `certs/` directory.

A sample configuration can be found in `cert_config-sample.yml`. This file includes all required fields.

## How to Use it for Device Posture verification with Cato

### On Cato Management Platform:
1. Add the rootCA.pem file to the CMA, using the path Access / Access Configuration / Client Access Control / Client Access / Signing Certificates
  - Create a New Certificate, give it a name and upload the rootCA.pem file
2. Create a Device Check to validate device certificates, using the path Resources / Objects / Device Posture / Device Checks
  - Create a new check, device test type "Device Certificate"
3. Create a new Device Posture Profile, or select an existing one, and add the newly created device certificate check on it
4. Add a new Client Connectivity Policy, using the path Access / Access Configuration / Client Access Control / Client Connectivity Policy
  - Create a new policy, or use an existing one, and associate the Device Posture Profile with the device certificate check on it
5. Enable the Client Connectivity Policy
  - Be aware that the default policy is to block access if no policy match is found

### On Windows
1. Install the device.p12 certificate
   - You can use the command below in privileged mode:
     ```powershell
     certutil -csp "Microsoft Software Key Storage Provider" -importpfx My <path-to-p12-file> NoExport
     ```
   - Install the certificate using the file explorer:
     - Double click on device.p12 file, it will open the Certificate Import Wizard
     - Select "Local Machine" and click next (it will ask to elevate privileges and you will need to have access to an administrative account)
     - Confirm the file name and click next
     - Type the password used for protecting the key file
     - Select the certificate repository "Personal"
     - Click finish
2. Confirm the certificate is installed
  - Use the app "certlm.msc" on windows, and certify that the certificate is installed under Local Machine / Personal ; or
  - Use the command below:
    ```powershell
    certutil -store My
    ```
    It will display the certificate.
3. Test the connection with the Cato ZTNA Client

### On MacOS
1. Open KeyChain Access app (select from Applications or search in Spotlight)
2. Select the login keychain
3. Drag and Drop the 'device_macos.p12' file to it


Notes: 
1. check if the Cato ZTNA Client version you are using supports device certificate check before enforcing it. The supported versions can be found in the [Cato Documentation](https://support.catonetworks.com/hc/en-us/articles/7387501459357-Creating-Device-Posture-Profiles-and-Device-Checks)
2. For MacOS, you don't need to change the trust settings for the certificate installed in this process

## Author
**Andre Gustavo Albuquerque**

[GitHub](https://github.com/andregca)


## License

Licensed under the [Apache License 2.0](https://www.apache.org/licenses/LICENSE-2.0).

---

For more details, refer to the instructions in the script or open an issue if something doesn’t work as expected.