const AWS = require('aws-sdk');
const ses = new AWS.SES({ region: 'ap-south-1' });

exports.handler = async (event) => {
  const { name, email, message } = JSON.parse(event.body);

  const params = {
    Destination: { ToAddresses: ['${emailRecipient}'] },
    Message: {
      Body: { Text: { Data: `From: ${name} <${email}>\n\n${message}` } },
      Subject: { Data: 'Portfolio Contact Form' }
    },
    Source: '${emailSender}'
  };

  await ses.sendEmail(params).promise();

  return {
    statusCode: 200,
    headers: { 'Access-Control-Allow-Origin': '*', 'Content-Type': 'application/json' },
    body: JSON.stringify({ message: 'Email sent' })
  };
};
