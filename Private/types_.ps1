function Add-IgnoreSSLWarningType {
    Add-Type -TypeDefinition @"
        using System;
        using System.Net;
        using System.Net.Security;
        using System.Security.Cryptography.X509Certificates;

        public static class IgnoreSSLWarning {
            public static bool ReturnTrue(object sender,
                X509Certificate certificate,
                X509Chain chain,
                SslPolicyErrors sslPolicyErrors) { return true; }

            public static RemoteCertificateValidationCallback GetDelegate() {
                return new RemoteCertificateValidationCallback(IgnoreSSLWarning.ReturnTrue);
            }
        }
"@ -ErrorAction Stop
}

Add-IgnoreSSLWarningType