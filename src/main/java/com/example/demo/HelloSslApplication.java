package com.example.demo;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.CommandLineRunner;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.boot.autoconfigure.web.ServerProperties;
import org.springframework.boot.web.server.Ssl;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

@SpringBootApplication
@RestController
public class HelloSslApplication implements CommandLineRunner {

	@Autowired
	ServerProperties serverProps;
	
	@GetMapping("/")
	public String greetings() {
		if (isSslEnabled()) {
			return "Hello from SSL";
		} else {
			return "Hello from plain http";
		}
	}


	private boolean isSslEnabled() {
		Ssl ssl = serverProps.getSsl();
		return ssl!=null && ssl.isEnabled();
	}
	
	public static void main(String[] args) {
		SpringApplication.run(HelloSslApplication.class, args);
	}


	@Override
	public void run(String... args) throws Exception {
		System.out.println("SSL is enabled? "+isSslEnabled());
	}

}
