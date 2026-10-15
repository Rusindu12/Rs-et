import unittest
from unittest.mock import patch

import main


class PromptTests(unittest.TestCase):
    def test_search_trigger_is_time_sensitive(self):
        self.assertTrue(main.should_search("What is the latest weather in Colombo today?"))
        self.assertTrue(main.should_search("ශ්‍රී ලංකාවේ නවතම තොරතුරු මොනවාද?"))
        self.assertFalse(main.should_search("Explain photosynthesis for Grade 8"))

    def test_prompt_contains_student_context_and_safe_sources(self):
        prompt = main.build_system_prompt(
            {"grade": 10, "subject": "Science", "chapter": "Energy"},
            [{"title": "A source", "url": "https://example.test", "snippet": "A short fact."}],
        )
        self.assertIn("Grade 10", prompt)
        self.assertIn("Science", prompt)
        self.assertIn("Energy", prompt)
        self.assertIn("untrusted reference material", prompt)
        self.assertIn("https://example.test", prompt)

    def test_chat_forwards_context_history_and_search_sources(self):
        source = {"title": "Official source", "url": "https://example.test", "snippet": "Updated information."}
        request = main.ChatRequest(
            message="What is the latest syllabus update?",
            context={"grade": 11, "subject": "Science", "chapter": "Energy"},
            history=[main.ChatTurn(role="user", content="Hello")],
        )
        with (
            patch.object(main, "LLM_ENDPOINT", "https://model.example/v1/chat/completions"),
            patch.object(main, "search_web", return_value=[source]) as search,
            patch.object(main, "call_model", return_value="A careful answer.") as call_model,
        ):
            result = main.chat(request)
        search.assert_called_once()
        self.assertEqual(result["reply"], "A careful answer.")
        self.assertEqual(result["sources"], [source])
        sent_messages = call_model.call_args.args[0]
        self.assertIn("Grade 11", sent_messages[0]["content"])
        self.assertIn("Official source", sent_messages[0]["content"])
        self.assertEqual(sent_messages[-1]["content"], request.message)
        self.assertEqual(sent_messages[-2]["role"], "user")


if __name__ == "__main__":
    unittest.main()
