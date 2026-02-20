export function closeIntent(
  event: any,
  message: string,
  sessionAttributes: Record<string, string> = {}
) {
  return {
    sessionState: {
      dialogAction: { type: 'Close' },
      intent: {
        name: event.sessionState.intent.name,
        state: 'Fulfilled',
      },
      sessionAttributes: {
        ...event.sessionState.sessionAttributes,
        ...sessionAttributes,
      },
    },
    messages: [
      {
        contentType: 'PlainText',
        content: message,
      },
    ],
  };
}
