package main

import (
	"crypto/rand"
	"crypto/rsa"
	"crypto/x509"
	"encoding/pem"
	"os"
)

func main() {
	privateKey, err := rsa.GenerateKey(rand.Reader, 2048)
	if err != nil {
		panic(err)
	}

	privateFile, err := os.Create("private.pem")
	if err != nil {
		panic(err)
	}
	defer privateFile.Close()

	privateKeyBytes := x509.MarshalPKCS1PrivateKey(privateKey)
	privateKeyBlock := &pem.Block{
		Type:  "RSA PRIVATE KEY",
		Bytes: privateKeyBytes,
	}
	err = pem.Encode(privateFile, privateKeyBlock)
	if err != nil {
		panic(err)
	}

	publicFile, err := os.Create("public.pem")
	if err != nil {
		panic(err)
	}
	defer publicFile.Close()

	publicKeyBytes := x509.MarshalPKCS1PublicKey(&privateKey.PublicKey)
	publicKeyBlock := &pem.Block{
		Type:  "RSA PUBLIC KEY",
		Bytes: publicKeyBytes,
	}
	err = pem.Encode(publicFile, publicKeyBlock)
	if err != nil {
		panic(err)
	}
}
