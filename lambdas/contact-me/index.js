// index.js

import { SESClient, SendEmailCommand } from "@aws-sdk/client-ses";

const ses = new SESClient({ region: process.env.AWS_REGION || "ap-south-1" });

export const handler = async (event) => {
  const { name, email, message } = JSON.parse(event.body);

  const params = {
    Source: process.env.EMAIL_SENDER,
    Destination: {
      ToAddresses: [process.env.EMAIL_RECIPIENT],
    },
    Message: {
      Subject: {
        Data: `New message from ${name}`,
      },
      Body: {
        Text: {
          Data: `Name: ${name}\nEmail: ${email}\n\nMessage:\n${message}`,
        },
      },
    },
  };

  try {
    const command = new SendEmailCommand(params);
    await ses.send(command);

    return {
      statusCode: 200,
      body: JSON.stringify({ message: "Email sent successfully" }),
    };
  } catch (err) {
    console.error("Error sending email:", err);
    return {
      statusCode: 500,
      body: JSON.stringify({ error: "Failed to send email" }),
    };
  }
};
